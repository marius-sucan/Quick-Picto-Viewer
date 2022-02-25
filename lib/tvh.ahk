; ==================================================================================================================================
; Function:       Functions for TreeView controls.
; Namespace:      TVH
; Tested with:    AHK 1.1.22.04 (A32/U32/U64)
; Tested on:      Win 8.1 (x64)
; Changelog:
;     1.0.00.00 - 23/08/2015 - just me     - initial release
;     1.0.10.10 - 16/01/2022 - Marius Șucan- removed reliance on RMO lib
; Common Parameters:
;     HTV      -  The handle (HWND) of the TreeView control.
;     ItemID   -  The item ID as returned by TV_Add().
; Return values:
;     Except as noted below, the functions will return a non-zero value on success (True), otherwise zero (False).
; Remarks:
;     All functions use the TreeView control's HWND and work independently of the current default Gui and TreeView.
;     All functions are designed to work with remote controls, too.
; ==================================================================================================================================
; Sets the checked state of the specified item.
; Additional parameters:
;     Mode  -  One of the values:
;              On:      Sets the checked state.
;              Off:     Removes the checked state.
;              Toggle:  Toggles the checked state.
; ==================================================================================================================================
TVH_Check(HTV, ItemID, Mode := "On") {
   Static Modes := {Off: "-Check", On: "Check", Toggle: 1}
   State := TVH_GetState(HTV, ItemID)
   If (State & 0x3000) && (Check := Modes[Mode]) {
      If (Mode = "Toggle")
         Check := State & 0x2000 ? "-Check" : "Check"
      Return TVH_SetState(HTV, ItemID, Check)
   }
   Return False
}

; ==================================================================================================================================
; Removes the specified item and all its children.
; Pass zero in ItemID to delete all items.
; ==================================================================================================================================
TVH_Delete(HTV, ItemID) {
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x1101, "Ptr", 0, "Ptr", ItemID, "Int")
}

; ==================================================================================================================================
; Begins in-place editing of the specified item's text.
; ==================================================================================================================================
TVH_EditLabel(HTV, ItemID) { ; TVM_EDITLABEL
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", A_IsUnicode ? 0x1141 : 0x110E, "Ptr", 0, "Ptr", ItemID, "UPtr")
}

; ==================================================================================================================================
; Expands or collapses the list of child items associated with the specified parent item, if any.
; Additional parameters:
;     Mode  -  One of the values:
;              On:      Expands the item.
;              Off:     Collapses the item.
;              Toggle:  Toggles the expanded state.
; ==================================================================================================================================
TVH_Expand(HTV, ItemID, Mode := "On") { ; TVM_EXPAND
   Static TVE := {Off: 0x0001, On: 0x0002, Toggle: 0x0003}
   If (Expand := TVE[Mode])
       Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x1102, "Ptr", Expand, "Ptr", ItemID, "Int")
   Return 0
}

; ==================================================================================================================================
; Retrieves the total number of checked items in the control.
; ==================================================================================================================================
TVH_GetCheckedCount(HTV) {
   CheckedCount := 0
   ItemID := 0
   While (ItemID := TVH_GetNextChecked(HTV, ItemID))
      CheckedCount++
   Return CheckedCount
}

; ==================================================================================================================================
; Retrieves the ID of the specified item's first child item (or 0 if none).
; ==================================================================================================================================
TVH_GetFirstChild(HTV, ItemID) { ; TVM_GETNEXTITEM, TVGN_CHILD
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0004, "Ptr", ItemID, "UPtr")
}

; ==================================================================================================================================
; Retrieves the ID of the first item that is visible in the tree-view window.
; ==================================================================================================================================
TVH_GetFirstVisible(HTV) { ; TVM_GETNEXTITEM, TVGN_FIRSTVISIBLE
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0005, "Ptr", 0, "UPtr")
}

; ==================================================================================================================================
; Retrieves the ID of the item under the mouse cursor (or 0 if none).
; ==================================================================================================================================
TVH_GetHovered(HTV) {
   Item := TVH_HitTest(HTV, Result)
   z := (Result & 0x0046) ? Item : 0   ; TVHT_ONITEM
   Return z
}

; ==================================================================================================================================
; Retrieves some of the specified item's attributes.
; Return values:
;     Returns an object containing the following keys on success, otherwise False.
;        Children:   Contains 1 if the item has children, otherwise zero.
;        Icon:       Contains the index of the item's icon in the TreeView's image list.
;        Param:      Contains the content of the item's lParem field.
;        Text:       Contains the text of the item
;        State:      Contains the numerical state flags of the item.
; ==================================================================================================================================
TVH_GetItem(HTV, ItemID) { ; TVM_GETITEMW : TVM_GETITEMA
   Static SizeOfText := 2048 ; characters

   VarSetCapacity(ItemText, SizeOfText << !!A_IsUnicode, 0) ; should be sufficient for both ANSI and Unicode
   SizeOfTVIX := 40 + (A_PtrSize * 5)
   VarSetCapacity(TVIX, SizeOfTVIX, 0) ; TVITEMEX
   NumPut(0x00FF, TVIX, 0, "UInt") ; mask
   NumPut(ItemID, TVIX, A_PtrSize, "UPtr") ; hItem
   NumPut(Remote ? RMO.Addr + SizeOfTVIX : &ItemText, TVIX, (A_PtrSize * 2) + 8, "UPtr") ; pszText
   NumPut(SizeOfText, TVIX, (A_PtrSize * 3) + 8, "UInt") ; cchTextMax
   PtrTVIX := Remote ? RMO.Addr : &TVIX

   If DllCall("SendMessage", "Ptr", HTV, "UInt", A_IsUnicode ? 0x113E : 0x110C, "Ptr", 0, "Ptr", PtrTVIX, "UInt")
   {
      VarSetCapacity(ItemText, -1)
      Return {State: NumGet(TVIX, A_PtrSize * 2, "UInt"), Text: ItemText, Icon: NumGet(TVIX, (A_PtrSize * 3) + 12, "Int") + 1
            , Children: NumGet(TVIX, (A_PtrSize * 3) + 20, "Int"), Param: NumGet(TVIX, (A_PtrSize * 3) + 24, "UPtr")}
   }
   Return False
}

; ==================================================================================================================================
; Retrieves the total number of items in the control.
; ==================================================================================================================================
TVH_GetItemCount(HTV) { ; TVM_GETCOUNT
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x1105, "Ptr", 0, "Ptr", 0, "Int")
}

; ==================================================================================================================================
; Retrieves the current height, in pixels, of the each tree-view item.
; ==================================================================================================================================
TVH_GetItemHeight(HTV) { ; TVM_GETITEMHEIGHT
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x111C, "Ptr", 0, "Ptr", 0, "Int")
}

; ==================================================================================================================================
; Retrieves the bounding rectangle for the specified item and indicates whether the item is visible.
; Additional parameters:
;     X, Y, W, H  -  ByRef variables to store the corresponding values of the rectangle.
;     TextOnly    -  If this parameter is True, the bounding rectangle includes only the text of the item.
;                    Otherwise, it includes the entire line that the item occupies in the tree-view control.
; ==================================================================================================================================
TVH_GetItemRect(HTV, ItemID, ByRef X, ByRef Y, ByRef W, ByRef H, TextOnly := True) { ; TVM_GETITEMRECT
   X := 0, Y := 0, W := 0, H := 0
   VarSetCapacity(RC, 16, 0)
   NumPut(ItemID, RC, 0, "UPtr")

   If DllCall("SendMessage", "Ptr", HTV, "UInt", 0x1104, "Ptr", !!TextOnly, "Ptr", &RC, "Int")
   {
      X := NumGet(RC, 0, "Int")
      Y := NumGet(RC, 4, "Int")
      W := NumGet(RC, 8, "Int") - X
      H := NumGet(RC, 12, "Int") - Y
      Return True
   }
   Return False
}

; ==================================================================================================================================
; Retrieves the ID of the last visible item in the tree (not the tree-view window).
; ==================================================================================================================================
TVH_GetLastVisible(HTV) { ; TVM_GETNEXTITEM, TVGN_LASTVISIBLE
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x000A, "Ptr", 0, "UPtr")
}

; ==================================================================================================================================
; Retrieves the mouse position relative to the client area of the TreeView.
; Additional parameters:
;     X, Y  -  ByRef variables to store the position.
; ==================================================================================================================================
TVH_GetMousePos(HTV, ByRef X, ByRef Y) {
   VarSetCapacity(Point, 8, 0)
   DllCall("GetCursorPos", "Ptr", &Point)
   DllCall("ScreenToClient", "Ptr", HTV, "Ptr", &Point)
   X := NumGet(Point, 0, "Int")
   Y := NumGet(Point, 4, "Int")
   Return (X & 0xFFFF) | ((Y & 0xFFFF) << 16) ; the returned value can be used directly with some messages
}

; ==================================================================================================================================
; Retrieves the ID of the next checked item below the specified item (or 0 if none).
; ==================================================================================================================================
TVH_GetNextChecked(HTV, ItemID := 0) {
   If (ItemID = 0)
   {
      ItemID := TVH_GetRoot(HTV)
      If TVH_IsChecked(HTV, ItemID)
         Return ItemID
   }

   Parents := []
   If (ParentID := TVH_GetParent(HTV, ItemID))
      Parents.Push(ParentID)

   NextChecked := 0
   While (NextChecked = 0) && (ItemID <> 0)
   {
      If (A_Index > 1) && TVH_IsChecked(HTV, ItemID)
      {
         NextChecked := ItemID
         Break
      }
      If (ChildID := TVH_GetFirstChild(HTV, ItemID))
      {
         Parents.Push(ItemID)
         ItemID := ChildID
      } Else ItemID := TVH_GetNextSibling(HTV, ItemID)

      If (ItemID = 0) && (ParentID := Parents.Pop())
         ItemID := TVH_GetNextSibling(HTV, ParentID)
   }
   Return NextChecked
}

; ==================================================================================================================================
; Retrieves the ID of the item below the specified item (or 0 if none).
; ==================================================================================================================================
TVH_GetNextItem(HTV, ItemID := 0) {  ; TVM_GETNEXTITEM, TVGN_NEXT
   Static Options := {Checked: True, Full: True}
   If (ItemID = 0)
      Return TVH_GetRoot(HTV)

   If (ChildID := TVH_GetFirstChild(HTV, ItemID))
      Return ChildID

   NextItem := 0
   While (NextItem = 0) && (ItemID <> 0)
   {
      NextItem := DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0001, "Ptr", ItemID, "UPtr")
      ItemID := NextItem = 0 ? TVH_GetParent(HLV, ItemID) : NextItem
   }
   Return NextItem
}

; ==================================================================================================================================
; Retrieves the ID of the sibling below the specified item (or 0 if none).
; ==================================================================================================================================
TVH_GetNextSibling(HTV, ItemID := 0) { ; TVM_GETNEXTITEM, TVGN_NEXT
   Static Options := {Checked: True, Full: True}
   If (ItemID = 0)
      Return TVH_GetRoot(HTV)

   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0001, "Ptr", ItemID, "UPtr")
}

; ==================================================================================================================================
; Retrieves the ID of next visible item that follows the specified item (or 0 if none).
; The specified item must be visible.
; ==================================================================================================================================
TVH_GetNextVisible(HTV, ItemID) { ; TVM_GETNEXTITEM, TVGN_NEXTVISIBLE
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0006, "Ptr", ItemID, "UPtr")
}

; ==================================================================================================================================
; Retrieves the value stored in the lParam field of the specified item.
; ==================================================================================================================================
TVH_GetParam(HTV, ItemID) { ; TVM_GETITEMW : TVM_GETITEMA
   SizeOfTVIX := 40 + (A_PtrSize * 5)
   VarSetCapacity(TVIX, SizeOfTVIX, 0) ; TVITEMEX
   NumPut(0x0004, TVIX, 0, "UInt") ; mask = TVIF_PARAM
   NumPut(ItemID, TVIX, A_PtrSize, "UPtr") ; hItem
   PtrTVIX := Remote ? RMO.Addr : &TVIX

   DllCall("SendMessage", "Ptr", HTV, "UInt", A_IsUnicode ? 0x113E : 0x110C, "Ptr", 0, "Ptr", PtrTVIX)
   Return NumGet(TVIX, 24 + (A_PtrSize * 3), "UPtr")
}

; ==================================================================================================================================
; Retrieves the ID of the parent node of the specified item (or 0 if none).
; ==================================================================================================================================
TVH_GetParent(HTV, ItemID) { ; TVM_GETNEXTITEM , TVGN_PARENT
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0003, "Ptr", ItemID, "UPtr")
}

; ==================================================================================================================================
; Retrieves the "full path" (i.e. the chain of nodes) of the specified item.
; Additional parameters:
;     Delimiter   -  The delimiter used to separate the parts of the path.
; ==================================================================================================================================
TVH_GetPath(HTV, ItemID, Delimiter := "\") {
   ItemPath := TVH_GetItem(HTV, ItemID).Text
   While (ItemID := TVH_GetParent(HTV, ItemID))
      ItemPath := TVH_GetItem(HTV, ItemID).Text . Delimiter . ItemPath
   Return ItemPath
}

; ==================================================================================================================================
; Retrieves the ID of the sibling above the specified item (or 0 if none).
; ==================================================================================================================================
TVH_GetPrev(HTV, ItemID) { ; TVM_GETNEXTITEM, TVGN_PREVIOUS
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0002, "Ptr", ItemID, "UPtr")
}

; ==================================================================================================================================
; Retrieves the ID of the first visible item that precedes the specified item (or 0 if none).
; The specified item must be visible.
; ==================================================================================================================================
TVH_GetPrevVisible(HTV, ItemID) { ; TVM_GETNEXTITEM, TVGN_PREVIOUSVISIBLE
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0007, "Ptr", ItemID, "UPtr")
}

; ==================================================================================================================================
; Retrieves the ID of the topmost or very first item of the tree-view control.
; ==================================================================================================================================
TVH_GetRoot(HTV) { ; TVM_GETNEXTITEM, TVGN_ROOT
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0000, "Ptr", 0, "UPtr")
}

; ==================================================================================================================================
; Retrieves the ID of the selected item (or 0 if none).
; ==================================================================================================================================
TVH_GetSelection(HTV) { ; TVM_GETNEXTITEM, TVGN_CARET
   Return  DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110A, "Ptr", 0x0009, "Ptr", 0, "UPtr")
}

; ==================================================================================================================================
; Retrieves the state flags of the specified item.
; ==================================================================================================================================
TVH_GetState(HTV, ItemID) { ; TVM_GETITEMSTATE
   Return  DllCall("SendMessage", "Ptr", HTV, "UInt", 0x1127, "Ptr", ItemID, "Ptr", 0xFFFF, "UInt")
}

; ==================================================================================================================================
; Obtains the number of items that can be fully visible in the client window of a tree-view control.
; ==================================================================================================================================
TVH_GetVisibleCount(HTV) { ; TVM_GETVISIBLECOUNT
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x1110, "Ptr", 0, "Ptr", 0, "Int")
}

; ==================================================================================================================================
; Determines the location of the specified point relative to the client area of a tree-view control.
; Additional parameters:
;     Result   -  Variable to store the result of the hit-testing.
;     X, Y     -  The position to use for hit-testing relative to the TreeView window.
;                 If one of the parameters is empty, the current cursor position will be used.
; ==================================================================================================================================
TVH_HitTest(HTV, ByRef Result, X := "", Y := "") { ; TVM_HITTEST
   If (X = "") || (Y = "")
      TVH_GetMousePos(HTV, X, Y)

   SizeOfTVHTI := 8 + (A_PtrSize * 2)
   VarSetCapacity(TVHTI, SizeOfTVHTI, 0)
   NumPut(X, TVHTI, 0, "Int")
   NumPut(Y, TVHTI, 4, "Int")
   Item := DllCall("SendMessage", "UPtr", HTV, "UInt", 0x1111, "Ptr", 0, "Ptr", &TVHTI, "UPtr")
   Result := NumGet(TVHTI, 8, "UInt")
   Return Item
}

; ==================================================================================================================================
; Inserts a new item at the specified position.
; Additional parameters:
;     ParentID    -  The ID of the new item's parent (omit it or specify 0 to add the item at the top level).
;     InsertAfter -  The ID of the sibling after which to insert the new item or one of the strings
;                    "First"  :  Adds the item as the first/top sibling.
;                    "Last"   :  Adds the item as the last/bottom sibling.
;                    "Root"   :  Adds the item as a root item.
;                    "Sort"   :  Inserts the item among its siblings in alphabetical order.
;     Options     -  String containing zero or more words from the list defined for TV_Add() (not case sensitive).
;                    Separate each word from the next with spaces or tabs.
; ==================================================================================================================================
TVH_Insert(HTV, ItemText, ParentID := 0, InsertAfter := "Last", Options := "") {
   Static TVI := {First: -65535, Last: -65534, Root: -65536, Sort: -65533}

   If TVI.HasKey(InsertAfter)
      InsertAfter := TVI[InsertAfter]
   If InsertAfter Is Not Integer
      Return 0

   Mask := 0x002B ; TVIF_TEXT | TVIF_IMAGE | TVIF_STATE | TVIF_SELECTEDIMAGE
   State := 0
   Icon := 0
   If RegExMatch(Options, "i)\bBold\b")
      State |= 0x0010
   If RegExMatch(Options, "i)\bCheck\b")
      State |= 0x2000
   If RegExMatch(Options, "i)\bIcon\K\d+", N)
      Icon := N - 1

   SizeOfText := StrLen(ItemText) << !!A_IsUnicode
   SizeOfTVINS := 40 + (A_PtrSize * 7)
   VarSetCapacity(TVINS, SizeOfTVINS, 0) ; TVINSERTSTRUCT
   NumPut(ParentID, TVINS, 0, "UPtr") ; hParent
   NumPut(InsertAfter, TVINS, A_PtrSize, "UPtr") ; hInsertAfter
   NumPut(Mask, TVINS, (A_PtrSize * 2), "UInt") ; mask
   NumPut(State, TVINS, (A_PtrSize * 4), "UInt") ; state
   NumPut(State, TVINS, (A_PtrSize * 4) + 4, "UInt") ; stateMask
   NumPut(Remote ? RMO.Addr + SizeOfTVINS : &TVINS, TVINS, (A_PtrSize * 4) + 8, "UPtr") ; pszText
   NumPut(Icon, TVINS, (A_PtrSize * 5) + 12, "Int") ; iImage
   NumPut(Icon, TVINS,  (A_PtrSize * 5) + 16, "Int") ; iSelectedImage
   PtrTVINS := Remote ? RMO.Addr : &TVINS

   If !(ItemID := DllCall("SendMessage", "Ptr", HTV, "UInt", A_IsUnicode ? 0x1132 : 0x1100, "Ptr", 0, "Ptr", PtrTVINS, "UPtr"))
      Return 0
   If RegExMatch(Options, "i)\bExpand\b")
      TVH_Expand(HTV, ItemID)
   If RegExMatch(Options, "i)\bVis\b")
      TVH_SetVisible(HTV, ItemID)
   If RegExMatch(Options, "i)\bSelect\b")
      TVH_Select(HTV, ItemID)
   If RegExMatch(Options, "i)\bVisFirst\b")
      TVH_SetFirstVisible(HTV, ItemID)
   Return ItemID
}

; ==================================================================================================================================
; Determines whether the specified item is bold.
; ==================================================================================================================================
TVH_IsBold(HTV, ItemID) { ; TVIS_BOLD = 0x0010
   Return !!(TVH_GetState(HTV, ItemID) & 0x0010)
}

; ==================================================================================================================================
; Determines whether the specified item is checked.
; ==================================================================================================================================
TVH_IsChecked(HTV, ItemID) {
   Return !!(TVH_GetState(HTV, ItemID) & 0x2000)
}

; ==================================================================================================================================
; Determines whether the specified item is expanded.
; ==================================================================================================================================
TVH_IsExpanded(HTV, ItemID) { ; TVIS_EXPANDED
   Return !!(TVH_GetState(HTV, ItemID) & 0x0020)
}

; ==================================================================================================================================
; Determines whether the specified item is a parent (i.e. has at least one child).
; ==================================================================================================================================
TVH_IsParent(HTV, ItemID) {
   Return !!TVH_GetFirstChild(HTV, ItemID)
}

; ==================================================================================================================================
; Determines whether the specified item is selected.
; ==================================================================================================================================
TVH_IsSelected(HTV, ItemID) { ; TVIS_SELECTED
   Return !!(TVH_GetState(HTV, ItemID) & 0x0002)
}

; ==================================================================================================================================
; Determines whether the specified item is visible.
; ==================================================================================================================================
TVH_IsVisible(HTV, ItemID) {
   Return TVH_GetItemRect(HTV, ItemID, X, X, X, X)
}

; ==================================================================================================================================
; Selects the specified item.
; ==================================================================================================================================
TVH_Select(HTV, ItemID) { ; TVM_SELECTITEM, TVGN_CARET
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110B, "Ptr", 0x0009, "Ptr", ItemID, "Int")
}

; ==================================================================================================================================
; Scrolls the specified item into view, and, if possible, displays it at the top of the control's window.
; ==================================================================================================================================
TVH_SetFirstVisible(HTV, ItemID) { ; TVM_SELECTITEM, TVGN_FIRSTVISIBLE
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x110B, "Ptr", 0x0005, "Ptr", ItemID, "Int")
}

; ==================================================================================================================================
; Sets the value stored in the lParam field of the specified item.
; Additional parameters:
;     Param    -  A pointer-sized integer value to store in the item's lParam field.
; ==================================================================================================================================
TVH_SetParam(HTV, ItemID, Param) { ; TVM_SETITEMW : TVM_SETITEMA
   SizeOfTVIX := 40 + (A_PtrSize * 5)
   VarSetCapacity(TVIX, SizeOfTVIX, 0) ; TVITEMEX
   NumPut(0x0004, TVIX, 0, "UInt") ; mask = TVIF_PARAM
   NumPut(ItemID, TVIX, A_PtrSize, "UPtr") ; hItem
   NumPut(Param, TVIX, 24 + (A_PtrSize * 3), "UPtr")
   PtrTVIX := Remote ? RMO.Addr : &TVIX
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", A_IsUnicode ? 0x113F : 0x110D, "Ptr", 0, "Ptr", PtrTVIX, "UInt")
}

; ==================================================================================================================================
; Sets the state attributes of the specified item.
; Additional parameters:
;     States*  -  one or more item states specified as numerical values or one of the string keys of ItemStates.
;                 To remove a state use the string keys and precede it with a minus sign (-) or pass a negative integer value.
; ==================================================================================================================================
TVH_SetState(HTV, ItemID, States*) { ; TVM_SETITEMW : TVM_SETITEMA
   Static ItemStates := {Bold: 0x10, Cut: 0x04, DropHilite: 0x08, Expand: 0x20, Select: 0x02, Check: 0xF000}
   State := StateMask := 0
   For Each, Value In States
   {
      If Value Is Integer
      {
         State |= Value > 0 ? Value : 0
         StateMask |= Abs(Value)
      } Else
      {
         Remove := False
         If (SubStr(Value, 1, 1) = "-")
         {
            Remove := True
            Value := SubStr(Value, 2)
         }
         
         If (S := ItemStates[Value])
         {
            StateMask |= S
            If (Value = "Check")
               State |= Remove ? 0x1000 : 0x2000
            Else
               State |= Remove ? 0 : S
         }
      }
   }

   If (StateMask)
   {
      SizeOfTVIX := 40 + (A_PtrSize * 5)
      VarSetCapacity(TVIX, SizeOfTVIX, 0) ; TVITEMEX
      NumPut(0x0008, TVIX, 0, "UInt") ; mask = TVIF_STATE
      NumPut(ItemID, TVIX, A_PtrSize, "UPtr") ; hItem
      NumPut(State, TVIX, A_PtrSize * 2, "UInt")
      NumPut(StateMask, TVIX, (A_PtrSize * 2) + 4, "UInt")
      PtrTVIX := Remote ? RMO.Addr : &TVIX
      Return DllCall("SendMessage", "Ptr", HTV, "UInt", A_IsUnicode ? 0x113F : 0x110D, "Ptr", 0, "Ptr", PtrTVIX, "UInt")
   }
   Return False
}

; ==================================================================================================================================
; Sets the text of the specified item.
; Additional parameters:
;     ItemText -  new text (caption).
; ==================================================================================================================================
TVH_SetText(HTV, ItemID, ItemText) { ; TVM_SETITEMW : TVM_SETITEMA
   SizeOfTVIX := 40 + (A_PtrSize * 5)
   SizeOfText := StrLen(ItemText) << !!A_IsUnicode
   VarSetCapacity(TVIX, SizeOfTVIX, 0) ; TVITEMEX
   NumPut(0x0001, TVIX, 0, "UInt") ; mask = TVIF_TEXT
   NumPut(ItemID, TVIX, A_PtrSize, "UPtr") ; hItem
   NumPut(Remote ? RMO.Addr + SizeOfTVIX : &ItemText, TVIX, (A_PtrSize * 2) + 8, "UPtr")
   RMO.Put(TVIX, 0, SizeOfTVIX)
   RMO.Put(ItemText, SizeOfTVIX, SizeOfText)
   PtrTVIX := Remote ? RMO.Addr : &TVIX
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", A_IsUnicode ? 0x113F : 0x110D, "Ptr", 0, "Ptr", PtrTVIX, "UInt")
}

; ==================================================================================================================================
; Scrolls the specified item into view.
; ==================================================================================================================================
TVH_SetVisible(HTV, ItemID) { ; TVM_ENSUREVISIBLE
   Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x1114, "Ptr", 0, "Ptr", ItemID, "UInt")
}

; ==================================================================================================================================
; ==================================================================================================================================
; Vista+ functions =================================================================================================================
; ==================================================================================================================================
; ==================================================================================================================================
TVH_SetExplorerTheme(HTV, Option := "") {
   ; Options:
   ;     R  -  Remove the TVS_HASLINES style using lines to show the hierarchy of items.
   ;     F  -  Set the TVS_FULLROWSELECT style. The entire row of the selected item is highlighted, and clicking anywhere on an
   ;           item's row selects it. The TVS_HASLINES style must be removed, also.
   If (TVH_OSVersion() > 5)
   {
      If (Option = "R") || (Option = "F")
      {
         Control, Style, -0x0002, , ahk_id %HTV%
         If (Option = "F")
            Control, Style, +0x1000, , ahk_id %HTV%
      }
      Return !DllCall("UxTheme.dll\SetWindowTheme", "Ptr", HTV, "WStr", "Explorer", "Ptr", 0)
   }
   Return False
}
; ----------------------------------------------------------------------------------------------------------------------------------
TVH_AutoHScroll(HTV, Set := True) {
   ; TVS_EX_AUTOHSCROLL = 0x0020
   Return TVH_SetExStyle(HTV, 0x0020, Set ? 0x0020 : 0)
}
; ----------------------------------------------------------------------------------------------------------------------------------
TVH_DoubleBuffer(HTV, Set := True) {
   ; TVS_EX_DOUBLEBUFFER = 0x0004
   Return TVH_SetExStyle(HTV, 0x0004, Set ? 0x0004 : 0)
}
; ----------------------------------------------------------------------------------------------------------------------------------
TVH_FadeInOutExpandos(HTV, Set := True) {
   ; TVS_EX_FADEINOUTEXPANDOS = 0x0040
   Return TVH_SetExStyle(HTV, 0x0040, Set ? 0x0040 : 0)
}
; ----------------------------------------------------------------------------------------------------------------------------------
TVH_RichToolTips(HTV, Set := True) {
   ; TVS_EX_RICHTOOLTIP = 0x0010
   Return TVH_SetExStyle(HTV, 0x0010, Set ? 0x0010 : 0)
}
; ----------------------------------------------------------------------------------------------------------------------------------
TVH_SetExStyle(HTV, StyleMask, Style) {
   ; TVM_SETEXTENDEDSTYLE = 0x0112
   If (TVH_OSVersion() > 5)
      Return DllCall("SendMessage", "Ptr", HTV, "UInt", 0x112C, "Ptr", StyleMask, "Ptr", Style)
   Return False
}

; ==================================================================================================================================
; For internal use!!! ==============================================================================================================
; ==================================================================================================================================
TVH_OSVersion() {
   Static OSVersion := DllCall("GetVersion", "UChar")
   Return OSVersion
}
; ----------------------------------------------------------------------------------------------------------------------------------
