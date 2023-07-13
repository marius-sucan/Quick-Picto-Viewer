
SelectFolderEx(StartingFolder:="", DlgTitle:="", OwnerHwnd:=0, OkBtnLabel:="", comboList:="", desiredDefault:=1, comboLabel:="", CustomPlaces:="", pickFoldersOnly:=1, usrFilters:="", defIndexFilter:=1, FileMustExist:=1, defaultEditField:="") {
; ==================================================================================================================================
; Shows a dialog to select a folder.
; Depending on the OS version the function will use either the built-in FileSelectFolder command (XP and previous)
; or the Common Item Dialog (Vista and later).
;
; Parameter:
;     StartingFolder -  the full path of a folder which will be preselected.
;     DlgTitle       -  a text used as window title (Common Item Dialog) or as text displayed withing the dialog.
;     FileMustExist  -  [bool] to allow or not opening files that do not exist
;     ----------------  Common Item Dialog only:
;     OwnerHwnd      -  HWND of the Gui which owns the dialog. If you pass a valid HWND the dialog will become modal.
;     BtnLabel       -  a text to be used as caption for the apply button.
;     comboList      -  a string with possible drop-down options, separated by `n [new line]
;     desiredDefault -  the default selected drop-down row
;     comboLabel     -  the drop-down label to display
;     CustomPlaces   -  custom directories that will be displayed in the left pane of the dialog; missing directories will be omitted; a string separated by `n [newline]
;     pickFoldersOnly - boolean option [0, 1]
;     defaultEditField - the text to display in the edit field by default when the open dialog shows up
;
;  Return values:
;     On success the function returns an object with the full path of the selected/file folder
;     and combobox selected [if any]; otherwise it returns an empty string.
;
; MSDN:
;     Common Item Dialog -> msdn.microsoft.com/en-us/library/bb776913%28v=vs.85%29.aspx
;     IFileDialog        -> msdn.microsoft.com/en-us/library/bb775966%28v=vs.85%29.aspx
;     IShellItem         -> msdn.microsoft.com/en-us/library/bb761140%28v=vs.85%29.aspx
; ==================================================================================================================================
; Source https://www.autohotkey.com/boards/viewtopic.php?f=6&t=18939
; by «just me»
; modified by Marius Șucan on jeudi 7 mai 2020
; to allow ComboBox and CustomPlaces
;
; options flags
; FOS_OVERWRITEPROMPT  = 0x2,
; FOS_STRICTFILETYPES  = 0x4,
; FOS_NOCHANGEDIR  = 0x8,
; FOS_PICKFOLDERS  = 0x20,
; FOS_FORCEFILESYSTEM  = 0x40,
; FOS_ALLNONSTORAGEITEMS  = 0x80,
; FOS_NOVALIDATE  = 0x100,
; FOS_ALLOWMULTISELECT  = 0x200,
; FOS_PATHMUSTEXIST  = 0x800,
; FOS_FILEMUSTEXIST  = 0x1000,
; FOS_CREATEPROMPT  = 0x2000,
; FOS_SHAREAWARE  = 0x4000,
; FOS_NOREADONLYRETURN  = 0x8000,
; FOS_NOTESTFILECREATE  = 0x10000,
; FOS_HIDEMRUPLACES  = 0x20000,
; FOS_HIDEPINNEDPLACES  = 0x40000,
; FOS_NODEREFERENCELINKS  = 0x100000,
; FOS_OKBUTTONNEEDSINTERACTION  = 0x200000,
; FOS_DONTADDTORECENT  = 0x2000000,
; FOS_FORCESHOWHIDDEN  = 0x10000000,
; FOS_DEFAULTNOMINIMODE  = 0x20000000,
; FOS_FORCEPREVIEWPANEON  = 0x40000000,
; FOS_SUPPORTSTREAMABLEITEMS  = 0x80000000

; IFileDialog vtable offsets
; 0   QueryInterface
; 1   AddRef 
; 2   Release 
; 3   Show 
; 4   SetFileTypes 
; 5   SetFileTypeIndex 
; 6   GetFileTypeIndex 
; 7   Advise 
; 8   Unadvise 
; 9   SetOptions 
; 10  GetOptions 
; 11  SetDefaultFolder 
; 12  SetFolder 
; 13  GetFolder 
; 14  GetCurrentSelection 
; 15  SetFileName 
; 16  GetFileName 
; 17  SetTitle 
; 18  SetOkButtonLabel 
; 19  SetFileNameLabel 
; 20  GetResult 
; 21  AddPlace 
; 22  SetDefaultExtension 
; 23  Close 
; 24  SetClientGuid 
; 25  ClearClientData 
; 26  SetFilter


   Static IID_IShellItem := 0
        , InitIID := 0
        , ShowDialog := A_PtrSize * 3
        , SetFileTypes := A_PtrSize * 4
        , SetFileTypeIndex := A_PtrSize * 5
        , SetOptions := A_PtrSize * 9
        , SetFolder := A_PtrSize * 12
        , SetDefaultEdit := A_PtrSize * 15 ; SetFileName
        , SetWinTitle := A_PtrSize * 17
        , SetOkButtonLabel := A_PtrSize * 18
        , GetResult := A_PtrSize * 20
        , AddPlaces := A_PtrSize * 21
        , ComDlgObj := {COMDLG_FILTERSPEC: ""}

   If !InitIID
   {
      InitIID := 1
      VarSetCapacity(IID_IShellItem, 16, 0)
      DllCall("Ole32.dll\IIDFromString", "WStr", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}", "Ptr", &IID_IShellItem)
   }

   SelectedFolder := ""
   OwnerHwnd := DllCall("IsWindow", "Ptr", OwnerHwnd, "UInt") ? OwnerHwnd : 0
   Try FileDialog := ComObjCreate("{DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7}", "{42f85136-db7e-439c-85f1-e4075d135fc8}")
   If !FileDialog
   {
      thisOption := (FileMustExist=1) ? 3 : 2
      FileSelectFolder, SelectedFolder, *%StartingFolder%, % thisOption, % DlgTitle
      Return SelectedFolder
   }

   VTBL := NumGet(FileDialog + 0, "UPtr") ; virtual table addresses
   dialogOptions := 0x8 | 0x800  ;  FOS_NOCHANGEDIR | FOS_PATHMUSTEXIST
   If (pickFoldersOnly=1)
      dialogOptions |= 0x20      ; FOS_PICKFOLDERS

   If (FileMustExist=1)
      dialogOptions |=  0x1000   ; FOS_FILEMUSTEXIST

   DllCall(NumGet(VTBL + SetOptions, "UPtr"), "Ptr", FileDialog, "UInt", dialogOptions, "UInt")
   If StartingFolder
   {
      If !DllCall("Shell32.dll\SHCreateItemFromParsingName", "WStr", StartingFolder, "Ptr", 0, "Ptr", &IID_IShellItem, "PtrP", FolderItem)
         DllCall(NumGet(VTBL + SetFolder, "UPtr"), "Ptr", FileDialog, "Ptr", FolderItem, "UInt")
   }

   If DlgTitle
      DllCall(NumGet(VTBL + SetWinTitle, "UPtr"), "Ptr", FileDialog, "WStr", DlgTitle, "UInt")
   If OkBtnLabel
      DllCall(NumGet(VTBL + SetOkButtonLabel, "UPtr"), "Ptr", FileDialog, "WStr", OkBtnLabel, "UInt")

   If (pickFoldersOnly!=1)
   {
       Filters := IsObject(usrFilters) ? usrFilters : {"All files": "*.*"}
       ObjSetCapacity(ComDlgObj, "COMDLG_FILTERSPEC", 2*Filters.Count() * A_PtrSize)
       for Description, FileTypes in Filters
       {
           ObjRawSet(ComDlgObj, "#" . A_Index, Trimmer(Description))
           , ObjRawSet(ComDlgObj, "@" . A_Index, Trimmer(StrReplace(FileTypes,"`n")))
           , NumPut(ObjGetAddress(ComDlgObj,"#" . A_Index)
           , ObjGetAddress(ComDlgObj,"COMDLG_FILTERSPEC") + A_PtrSize * 2*(A_Index-1))        ; COMDLG_FILTERSPEC.pszName
           , NumPut(ObjGetAddress(ComDlgObj,"@" . A_Index)
           , ObjGetAddress(ComDlgObj,"COMDLG_FILTERSPEC") + A_PtrSize * (2*(A_Index-1)+1))    ; COMDLG_FILTERSPEC.pszSpec
       }

       ; IFileDialog::SetFileName method 
       ; https://docs.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifiledialog-setfilename
       If defaultEditField
          DllCall(NumGet(VTBL + SetDefaultEdit), "UPtr", FileDialog, "WStr", defaultEditField)

       ; IFileDialog::SetFileTypes method
       ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775980(v=vs.85).aspx
       DllCall(NumGet(VTBL + SetFileTypes), "UPtr", FileDialog, "UInt", Filters.Count(), "UPtr", ObjGetAddress(ComDlgObj,"COMDLG_FILTERSPEC"))

       ; IFileDialog::SetFileTypeIndex method
       ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775978(v=vs.85).aspx
       If defIndexFilter
          DllCall(NumGet(VTBL + SetFileTypeIndex), "UPtr", FileDialog, "UInt", defIndexFilter)
   }

   If CustomPlaces
   {
      Loop, Parse, CustomPlaces, `n
      {
          Directory := Trim(A_LoopField, "`r `n `t`f`v`b")
          If FolderExist(Directory)
          {
             foo := 1
             DllCall("Shell32.dll\SHParseDisplayName", "UPtr", &Directory, "Ptr", 0, "UPtrP", PIDL, "UInt", 0, "UInt", 0)
             DllCall("Shell32.dll\SHCreateShellItem", "Ptr", 0, "Ptr", 0, "UPtr", PIDL, "UPtrP", IShellItem)
             ObjRawSet(ComDlgObj, IShellItem, PIDL)
             ; IFileDialog::AddPlace method
             ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775946(v=vs.85).aspx
             DllCall(NumGet(VTBL + AddPlaces), "UPtr", FileDialog, "UPtr", IShellItem, "UInt", foo)
          }
      }
   }

   If (comboList && comboLabel)
   {
      Try If ((FileDialogCustomize := ComObjQuery(FileDialog, "{e6fdd21a-163f-4975-9c8c-a69f1ba37034}")))
      {
         groupId := 616 ; arbitrarily chosen IDs
         comboboxId := 93270
         DllCall(NumGet(NumGet(FileDialogCustomize+0)+26*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", groupId, "WStr", comboLabel) ; IFileDialogCustomize::StartVisualGroup
         DllCall(NumGet(NumGet(FileDialogCustomize+0)+6*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId) ; IFileDialogCustomize::AddComboBox
         ; DllCall(NumGet(NumGet(FileDialogCustomize+0)+19*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt", itemOneId, "WStr", "Current folder") ; IFileDialogCustomize::AddControlItem
         
         entriesArray := []
         Loop, Parse, comboList,`n
         {
             elementu := Trim(A_LoopField, "`r `n `t`f`v`b")
             If elementu
             {
                Random, varA, 2, 900
                Random, varB, 2, 900
                thisID := varA varB
                If (A_Index=desiredDefault)
                   desiredIDdefault := thisID

                entriesArray[thisId] := elementu
                DllCall(NumGet(NumGet(FileDialogCustomize+0)+19*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt", thisID, "WStr", elementu)
             }
         }

         DllCall(NumGet(NumGet(FileDialogCustomize+0)+25*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt", desiredIDdefault) ; IFileDialogCustomize::SetSelectedControlItem
         DllCall(NumGet(NumGet(FileDialogCustomize+0)+27*A_PtrSize), "Ptr", FileDialogCustomize) ; IFileDialogCustomize::EndVisualGroup
      }

   }

   If !DllCall(NumGet(VTBL + ShowDialog, "UPtr"), "Ptr", FileDialog, "Ptr", OwnerHwnd, "UInt")
   {
      If !DllCall(NumGet(VTBL + GetResult, "UPtr"), "Ptr", FileDialog, "PtrP", ShellItem, "UInt")
      {
         GetDisplayName := NumGet(NumGet(ShellItem + 0, "UPtr"), A_PtrSize * 5, "UPtr")
         If !DllCall(GetDisplayName, "Ptr", ShellItem, "UInt", 0x80028000, "PtrP", StrPtr) ; SIGDN_DESKTOPABSOLUTEPARSING
         {
            SelectedFolder := StrGet(StrPtr, "UTF-16")
            DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
         }

         ObjRelease(ShellItem)
         if (FileDialogCustomize && entriesArray.Count())
         {
            if (DllCall(NumGet(NumGet(FileDialogCustomize+0)+24*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt*", selectedItemId) == 0)
            { ; IFileDialogCustomize::GetSelectedControlItem
               if selectedItemId
                  thisComboSelected := entriesArray[selectedItemId]
            }   
         }
      }
   }
   If (FolderItem)
      ObjRelease(FolderItem)

   if (FileDialogCustomize)
      ObjRelease(FileDialogCustomize)

   ObjRelease(FileDialog)
   r := []
   r.SelectedDir := SelectedFolder
   r.SelectedCombo := thisComboSelected
   Return r
}

;------------------------------
;
; Function: Dlg_OpenSaveFile
;
; Description:
;
;   Internal function used by <Dlg_OpenFile> and <Dlg_SaveFile> to create an
;   Open or Save dialog.
;
; Type:
;
;   Internal function.  Subject to change.  Do not call directly.
;
; Parameters:
;
;   p_Type - [Internal function only] Set to "O" or "Open" to create a Open
;       dialog.  Set to "S" or "Save" to create a Save dialog.
;
;   hOwner - A handle to the window that owns the dialog box.  This parameter
;       can be any valid window handle or it can be set to 0 or null if the
;       dialog box has no owner.  Note: A valid window handle must be specified
;       if the OFN_SHOWHELP flag is included (explicitly or implicitly).
;
;   p_Title - A string to be placed in the title bar of the dialog box.  If set
;       to null (the default), the system uses the default title (that is,
;       "Open" or "Save As").
;
;   p_Filter - One or more filter strings that determine which files are
;       displayed. [Optional] Each filter string is composed of two parts.
;       The first part describes the filter.  For example: "Text Files".  The
;       second part specifies the filter pattern and must be enclosed in
;       parenthesis.  For example "(*.txt)".  To specify multiple filter
;       patterns for a single display string, use a semicolon to separate the
;       patterns.  For example: "(*.txt;*.doc;*.bak)".  A pattern string can be
;       a combination of valid file name characters and the asterisk ("*")
;       wildcard character.  Do not include spaces in the pattern string.
;       Multiple filter strings are delimited by the "|" character.  For
;       example: "Text Files (*.txt)|Backup Files (*.bak)".
;
;   p_FilterIndex - 1-based filter index.  If set to null (the default), 1 is
;       used.  The index determines which filter string is pre-selected in the
;       "File Types" control.
;
;   p_Root - Root (startup) directory and/or default file name.  To specify a
;       root directory only, include the full path of the directory with a
;       trailing "\" character.  Ex: "C:\Program Files\".  To specify a startup
;       directory and a default file, include the full path of the default file.
;       Ex: "C:\My Stuff\My Program.html".  To specify a default file only,
;       include the file name without the path.  Ex: "My Program.html".  If a
;       default file name is included, the file name (sans the path) is shown in
;       the dialog's "File name:" edit field. If this parameter is set to null
;       (the default), the startup directory will be set using the OS default
;       for this dialog.  See the documentation for the OPENFILENAME structure
;       (lpstrInitialDir member) for more information.
;
;   p_DfltExt - Extension to append when none is given.  Ex: "txt".  The string
;       should not contain a period (".").  If this parameter is null (the
;       default) and the user fails to type an extension, no extension is
;       appended.
;
;   r_Flags - Flags used to initialize the dialog. [Optional, Input/Output] See
;       the *Flags* section for the details.
;
;   p_HelpHandler - Name of a developer-created function that is called when the
;       the user presses the Help button on the dialog. [Optional] See the *Help
;       Handler* section for the details.  Note: The OFN_SHOWHELP flag is
;       automatically added if this parameter contains a valid function name.
;
; Flags:
;
;   On input, the r_Flags parameter contains flags that are used to initialize
;   and/or determine the behavior of the dialog.  If set to 0 or null and
;   p_Type="O" (Open dialog), the OFN_FILEMUSTEXIST and OFN_HIDEREADONLY flags
;   are added automatically.  If r_Flag contains an interger value, the
;   parameter is assumed to contain bit flags.  See the function's static
;   variables for a list a valid bit flags.  Otherwise, text flags are assumed.
;   The following space-delimited text flags can be used.
;
;   AllowMultiSelect - Specifies that the File Name list box allows multiple
;       selections.
;
;   CreatePrompt - [Open dialog only] If the user specifies a file that does not
;       exist, this flag causes the dialog to prompt the user for permission to
;       create the file.
;
;   DontAddToRecent - Prevents the system from adding a link to the selected
;       file in the file system directory that contains the user's most recently
;       used documents.
;
;   Ex_NoPlacesBar - If specified, the places bar is not displayed.  If not
;       specified, Explorer-style dialog boxes include a places bar containing
;       icons for commonly-used folders, such as Favorites and Desktop.
;
;   FileMustExist - [Open dialog only (with implicit exceptions)] This flag
;       ensures that the user can only type names of existing files in the File
;       Name entry.  A message box is generated if an invalid file is entered.
;       Opinion: This flag should be specified in most circumstances.
;       IMPORTANT: If this flag is specified (explicitly or implicitly), the
;       PathMustExist flag is also used.  See the PathMustExist flag for the
;       rules that are enforced for both the Open and Save dialogs.
;
;   ForceShowHidden - Forces the showing of system and hidden files, thus
;       overriding the user setting to show or not show hidden files.  However,
;       a file that is marked both system and hidden is not shown.  Observation:
;       This flag does not work as expected on Windows XP (may also occur on
;       other (or all) versions of Windows).  When a directory that includes a
;       hidden file is first displayed (including the initial directory), hidden
;       files are not shown.  Clicking on the "Open" or "Save" button without
;       selecting a file will redisplay the list of files to include the hidden
;       file(s).
;
;   HideReadOnly - [Open dialog only] Hides the Read Only check box.  This flag
;       should be specified in most circumstances.
;
;   NoChangeDir - Restores the current directory to its original value if the
;       user changed the directory while searching for files.
;
;   NoDereferenceLinks - Directs the dialog box to return the path and file name
;       of the selected shortcut (.LNK) file.  If this value is not specified,
;       the dialog box returns the path and file name of the file referenced by
;       the shortcut.  Observation: For shortcuts to OS files, this works as
;       expected.  However, for other types of shortcuts, Ex: shortcuts to a web
;       site, the return value may not be what is expected.  Test thoroughly
;       before using.
;
;   NoReadOnlyReturn - [Save dialog only] Prevents the dialog from returning
;       names of existing files that have the read-only attribute.  If a
;       read-only file is selected, a message dialog is generated.  The dialog
;       will persist until the selection does not include a file with read-only
;       attribute.
;
;   NoTestFileCreate - By default, the dialog box creates a zero-length test
;       file to determine whether a new file can be created in the selected
;       directory.  Set this flag to prevent the creation of this test file.
;       This flag should be specified if the application saves the file on a
;       network drive with Create but no Modify privileges.
;
;   NoValidate - Specifies that the common dialog boxes allow invalid characters
;       in the returned file name.
;
;   OverwritePrompt - [Save dialog only] Causes the dialog to generate a message
;       box if the selected file already exists.  The user must confirm whether
;       to overwrite the file.
;
;   PathMustExist - Specifies that the user can type only existing paths in the
;       File Name entry.  A message box is generated if an invalid path is
;       entered.  Note: This flag is automatically added if the FileMustExist
;       flag is used.
;
;   ReadOnly - [Open dialog only] Causes the Read Only check box to be selected
;       initially when the dialog box is created.
;
;   ShowHelp - Causes the dialog to display the Help button.
;
;   On output, the r_Flag parameter may contain bit flags that inform the
;   developer of conditions of the dialog at the time the dialog was closed.
;   The following bit flags can be set.
;
;   OFN_READONLY (0x1) - [Open dialog only] This flag is set if the Read Only
;       check box was checked when the dialog was closed.
;
;   OFN_EXTENSIONDIFFERENT (0x400) - This flag is set if the p_DfltExt parameter
;       is not null and the user selected or typed a file name extension that
;       differs from the p_DfltExt parameter.  Exception: This flag is not set
;       if multiple files are selected.
;
; Returns:
;
;   Selected file name(s) or null if cancelled.  If more then one file is
;   selected, each file is delimited by a new line ("`n") character.
;
; Remarks:
;
;   If the user changes the directory while using the Open or Save dialog, the
;   script's working directory will also be changed.  If desired, use the
;   "NoChangeDir" flag (r_Flags parameter) to prevent this from occurring or use
;   the *SetWorkingDir* command to restore the working directory after calling
;   this function.
;
; Help Handler:
;
;   The "Help Handler" is an optional developer-created function that is called
;   when the user presses the Help button on the dialog.
;
;   The handler function must have at least 2 parameters.  Additional parameters
;   are allowed but must be optional (defined with a default value).  The
;   required parameters are defined/used as follows, and in the following order:
;
;       hDialog - The handle to the dialog window.
;
;       lpInitStructure - A pointer to the initialization structure for the
;           common dialog box. For this handler, the pointer is to a
;           OPENFILENAME structure.
;
;   It's up to the developer to determine what commands are performed in this
;   function but displaying some sort of help message/document is what is
;   expected.
;
;   To avoid interference with the operation of the dialog, the handler should
;   either 1) finish quickly or 2) any dialogs displayed via the handler should
;   be modal.  See the scripts included with this project for an example.
;
;-------------------------------------------------------------------------------
Dlg_OpenSaveFile(p_Type,hOwner:=0,p_Title:="",p_Filter:="",p_FilterIndex:="",p_Root:="",p_DfltExt:="",ByRef r_Flags:=0,p_HelpHandler:="") {
; function source: https://www.autohotkey.com/boards/viewtopic.php?f=6&t=462
; by jballi
; modified by Marius Șucan

    Static Dummy16963733
          ,s_strFileMaxSize:=932768 ; ansi limit 32768
                ;-- This is the ANSI byte limit.  For consistency, this value
                ;   is also used to set the the maximum number characters that
                ;   used in Unicode.  Note: Only the first entry contains the
                ;   folder name so 32K characters can hold a very large number
                ;   of file names.

          ,HELPMSGSTRING:="commdlg_help"
                ;-- Registered message string for the Help button on common
                ;   dialogs

          ,OPENFILENAME
                ;-- Static OPENFILENAME structure.  Also used by the hook
                ;   callback and the help message.

          ;-- Open File Name flags
          ,OFN_ALLOWMULTISELECT    :=0x200
          ,OFN_CREATEPROMPT        :=0x2000
          ,OFN_DONTADDTORECENT     :=0x2000000
          ,OFN_ENABLEHOOK          :=0x20

          ,OFN_EXPLORER            :=0x80000
                ;-- This flag is set by default.  This function does not work
                ;   with the old-style dialog box.

          ,OFN_EXTENSIONDIFFERENT  :=0x400
                ;-- Output flag only.

          ,OFN_FILEMUSTEXIST       :=0x1000
          ,OFN_FORCESHOWHIDDEN     :=0x10000000
          ,OFN_HIDEREADONLY        :=0x4

          ,OFN_NOCHANGEDIR         :=0x8
          ,OFN_NODEREFERENCELINKS  :=0x100000

          ,OFN_NOREADONLYRETURN    :=0x8000
          ,OFN_NOTESTFILECREATE    :=0x10000
          ,OFN_NOVALIDATE          :=0x100
          ,OFN_OVERWRITEPROMPT     :=0x2
          ,OFN_PATHMUSTEXIST       :=0x800
          ,OFN_READONLY            :=0x1
          ,OFN_SHOWHELP            :=0x10

          ;-- Open File Name extended flags
          ,OFN_EX_NOPLACESBAR      :=0x1
                ;-- Note: This flag is only available as a text flag, i.e.
                ;   "NoPlacesBar".

          ;-- Misc.
          ,TCharSize:=A_IsUnicode ? 2:1

    ;[==============]
    ;[  Parameters  ]
    ;[==============]
    ;-- Type
    p_Type:=SubStr(p_Type,1,1)
    StringUpper p_Type,p_Type
        ;-- Convert to uppercase to simplify processing

    if p_Type not in O,S
        p_Type:="O"

    ;-- Filter
    if p_Filter is Space
        p_Filter:="All Files (*.*)"

    ;-- Flags
    l_Flags  :=OFN_EXPLORER
    l_FlagsEx:=0
    if not r_Flags  ;-- Zero, blank, or null
    {
        if (p_Type="O")  ;-- Open dialog only
            l_Flags|=OFN_FILEMUSTEXIST|OFN_HIDEREADONLY
    } else
    {
        ;-- Bit flags
        if r_Flags is Integer
        {
            l_Flags|=r_Flags
        } else
        {
            ;-- Convert text flags into bit flags
            Loop Parse,r_Flags,%A_Tab%%A_Space%,%A_Tab%%A_Space%
            {
                if A_LoopField is not Space
                {
                    if OFN_%A_LoopField% is Integer
                    {
                        if InStr(A_LoopField,"ex_")
                            l_FlagsEx|=OFN_%A_LoopField%
                        else
                            l_Flags|=OFN_%A_LoopField%
                    }
                }
            }
        }
    }

    if IsFunc(p_HelpHandler)
        l_Flags|=OFN_SHOWHELP

    ; if (p_Type="O") and (l_Flags & OFN_ALLOWMULTISELECT)
    ;     l_Flags|=OFN_ENABLEHOOK

    ;-- Create and, if needed, populate the buffer used to initialize the
    ;   File Name Edit control.  The dialog will also use this buffer to return
    ;   the file(s) selected.
    VarSetCapacity(strFile,s_strFileMaxSize*TCharSize,0)
    SplitPath p_Root,l_RootFileName,l_RootDir
    if l_RootFileName is not Space
    {
        DllCall("RtlMoveMemory"
            ,"Str",strFile
            ,"Str",l_RootFileName
            ,"UInt",(StrLen(l_RootFileName)+1)*TCharSize)
    }

    ;-- Convert p_Filter into the format required by the API
    VarSetCapacity(strFilter,StrLen(p_Filter)*(A_IsUnicode ? 5:3),0)
        ;-- Enough space for the full description _and_ file pattern(s) of all
        ;   filter strings (ANSI and Unicode) plus null characters between all
        ;   of the pieces and a double null at the end.

    l_Offset:=&strFilter
    Loop Parse,p_Filter,|
    {
        ;-- Break the filter string into 2 parts
        l_LoopField:=Trim(A_LoopField," `f`n`r`t`v")
            ;-- Assign and remove all leading/trailing white space

        l_Part1:=l_LoopField
            ;-- Part 1: The entire filter string which includes the description
            ;   and the file pattern(s) in parenthesis.  This is what is
            ;   displayed in  the "File Of Types" or the "Save As Type"
            ;   drop-down.

        l_Part2:=SubStr(l_LoopField,InStr(l_LoopField,"(")+1,-1)
            ;-- Part 2: File pattern(s) sans parenthesis.  The dialog uses this
            ;   to filter the files that are displayed.

        ;-- Calculate the length of the pieces
        l_lenPart1:=(StrLen(l_LoopField)+1)*TCharSize
            ;-- Size includes terminating null

        l_lenPart2:=(StrLen(l_Part2)+1)*TCharSize
            ;-- Size includes terminating null

        ;-- Copy the pieces to the filter string.  Each piece includes a
        ;   terminating null character.
        DllCall("RtlMoveMemory","Ptr",l_Offset,"Str",l_Part1,"UInt",l_lenPart1)
        DllCall("RtlMoveMemory","Ptr",l_Offset+l_lenPart1,"Str",l_Part2,"UInt",l_lenPart2)                          ;-- Length

        ;-- Calculate the offset of the next filter string
        l_Offset+=l_lenPart1+l_lenPart2
    }

    ;[==================]
    ;[  Pre-Processing  ]
    ;[==================]
    ;-- Create and populate the OPENFILENAME structure
    lStructSize:=VarSetCapacity(OPENFILENAME,(A_PtrSize=8) ? 152:88,0)
    NumPut(lStructSize,OPENFILENAME,0,"UInt")
        ;-- lStructSize
    NumPut(hOwner,OPENFILENAME,(A_PtrSize=8) ? 8:4,"Ptr")
        ;-- hwndOwner
    NumPut(&strFilter,OPENFILENAME,(A_PtrSize=8) ? 24:12,"Ptr")
        ;-- lpstrFilter
    NumPut(p_FilterIndex,OPENFILENAME,(A_PtrSize=8) ? 44:24,"UInt")
        ;-- nFilterIndex
    NumPut(&strFile,OPENFILENAME,(A_PtrSize=8) ? 48:28,"Ptr")
        ;-- lpstrFile
    NumPut(s_strFileMaxSize,OPENFILENAME,(A_PtrSize=8) ? 56:32,"UInt")
        ;-- nMaxFile
    NumPut(&l_RootDir,OPENFILENAME,(A_PtrSize=8) ? 80:44,"Ptr")
        ;-- lpstrInitialDir
    NumPut(&p_Title,OPENFILENAME,(A_PtrSize=8) ? 88:48,"Ptr")
        ;-- lpstrTitle
    NumPut(l_Flags,OPENFILENAME,(A_PtrSize=8) ? 96:52,"UInt")
        ;-- Flags
    NumPut(&p_DfltExt,OPENFILENAME,(A_PtrSize=8) ? 104:60,"Ptr")
        ;-- lpstrDefExt
    NumPut(l_FlagsEx,OPENFILENAME,(A_PtrSize=8) ? 148:84,"UInt")
        ;-- FlagsEx

    ;[===============]
    ;[  Show dialog  ]
    ;[===============]
    if (p_type="O")
        RC:=DllCall("comdlg32\GetOpenFileName" . (A_IsUnicode ? "W":"A"),"Ptr",&OPENFILENAME)
    else
        RC:=DllCall("comdlg32\GetSaveFileName" . (A_IsUnicode ? "W":"A"),"Ptr",&OPENFILENAME)

    ;[===================]
    ;[  Post-Processing  ]
    ;[===================]
    ;-- If needed, turn off monitoring of help message
    if l_HelpMsg
        OnMessage(l_HelpMsg,"")  ;-- Turn off monitoring

    ;-- Dialog canceled?
    if (RC=0)
        Return

    ;-- Rebuild r_Flags for output
    r_Flags  :=0
    l_Flags:=NumGet(OPENFILENAME,(A_PtrSize=8) ? 96:52,"UInt")
    ; n_FilterIndex := NumGet(OPENFILENAME,(A_PtrSize=8) ? 44:24,"UInt")
    ;-- Flags

    if p_DfltExt is not Space  ;-- Flag is ignored unless p_DfltExt contains a value
    {
        if l_Flags & OFN_EXTENSIONDIFFERENT
            r_Flags|=OFN_EXTENSIONDIFFERENT
    }

    if (p_Type="O")  ;-- i.e. flag is ignored if using the Save dialog
    {
        if l_Flags & OFN_ALLOWMULTISELECT
        {
            ; Hook was used to collect ReadOnly status.  Collect the ReadOnly
            ; status from the hook function.
            Sleep, 1
            ; if Dlg_OFNHookCallback("GetReadOnly","","","")
            ; r_Flags|=OFN_READONLY
        } else
        {
            ;-- Hook was NOT used to collect ReadOnly status.  Determine status from l_Flags
            if l_Flags & OFN_READONLY
                r_Flags|=OFN_READONLY
        }
    }

    ;-- Extract file(s) from the buffer
    l_FileList:=""
    l_Offset  :=&strFile
    Loop
    {
        ;-- Get next
        l_Next:=StrGet(l_Offset,-1)

        ;-- End of list?
        if not StrLen(l_Next)
        {
            ;-- If end-of-list occurs on the 2nd iteration, it means that only
            ;   one file was selected
            if (A_Index=2)
                l_FileList:=l_FileName
            Break
        }

        ;-- Assign to working variable
        l_FileName:=l_Next

        ;-- Update the offset for the next iteration
        l_Offset+=(StrLen(l_FileName)+1)*TCharSize

        ;-- If this is the first iteration, we have to wait until the next loop
        ;   before we can determine if this is a directory or file and if a
        ;   file, if it is the only file selected.
        if (A_Index=1)
        {
            l_Dir:=l_FileName
            ;-- Windows adds "\" character when in root of the drive but doesn't
            ;   add it otherwise.  Adjust if needed.
            if (StrLen(l_Dir)<>3 && p_Type="O")
                l_Dir.="\"

            ;-- Continue to next
            Continue
        }

        ;-- Add the file to the list
        if (p_Type="O")
           l_FileList.=(StrLen(l_FileList) ? "`n":"") . l_Dir . l_FileName
        else
           l_FileList := Trim(Trim(l_Dir, "\"))
    }

    Return l_FileList
}

SHGetKnownFolderPath(FOLDERID, KF_FLAG:=0) {                  ;   By SKAN on D356 @ tiny.cc/t-75602 
   ; FOLDERID_AccountPictures         := "{008ca0b1-55b4-4c56-b8a8-4de4b299d3be}" ; Windows  8
   ; FOLDERID_AddNewPrograms          := "{de61d971-5ebc-4f02-a3a9-6c82895e5c04}"  
   ; FOLDERID_AdminTools              := "{724EF170-A42D-4FEF-9F26-B60E846FBA4F}"  
   ; FOLDERID_AppDataDesktop          := "{B2C5E279-7ADD-439F-B28C-C41FE1BBF672}" ; Windows  10, version 1709
   ; FOLDERID_AppDataDocuments        := "{7BE16610-1F7F-44AC-BFF0-83E15F2FFCA1}" ; Windows  10, version 1709
   ; FOLDERID_AppDataFavorites        := "{7CFBEFBC-DE1F-45AA-B843-A542AC536CC9}" ; Windows  10, version 1709
   ; FOLDERID_AppDataProgramData      := "{559D40A3-A036-40FA-AF61-84CB430A4D34}" ; Windows  10, version 1709
   ; FOLDERID_ApplicationShortcuts    := "{A3918781-E5F2-4890-B3D9-A7E54332328C}" ; Windows  8
   ; FOLDERID_AppsFolder              := "{1e87508d-89c2-42f0-8a7e-645a0f50ca58}" ; Windows  8
   ; FOLDERID_AppUpdates              := "{a305ce99-f527-492b-8b1a-7e76fa98d6e4}"  
   ; FOLDERID_CameraRoll              := "{AB5FB87B-7CE2-4F83-915D-550846C9537B}" ; Windows  8.1
   ; FOLDERID_CDBurning               := "{9E52AB10-F80D-49DF-ACB8-4330F5687855}"  
   ; FOLDERID_ChangeRemovePrograms    := "{df7266ac-9274-4867-8d55-3bd661de872d}"  
   ; FOLDERID_CommonAdminTools        := "{D0384E7D-BAC3-4797-8F14-CBA229B392B5}"  
   ; FOLDERID_CommonOEMLinks          := "{C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D}"  
   ; FOLDERID_CommonPrograms          := "{0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8}"  
   ; FOLDERID_CommonStartMenu         := "{A4115719-D62E-491D-AA7C-E74B8BE3B067}"  
   ; FOLDERID_CommonStartup           := "{82A5EA35-D9CD-47C5-9629-E15D2F714E6E}"  
   ; FOLDERID_CommonTemplates         := "{B94237E7-57AC-4347-9151-B08C6C32D1F7}"  
   ; FOLDERID_ComputerFolder          := "{0AC0837C-BBF8-452A-850D-79D08E667CA7}"  
   ; FOLDERID_ConflictFolder          := "{4bfefb45-347d-4006-a5be-ac0cb0567192}" ; Windows  Vista
   ; FOLDERID_ConnectionsFolder       := "{6F0CD92B-2E97-45D1-88FF-B0D186B8DEDD}"  
   ; FOLDERID_Contacts                := "{56784854-C6CB-462b-8169-88E350ACB882}" ; Windows  Vista
   ; FOLDERID_ControlPanelFolder      := "{82A74AEB-AEB4-465C-A014-D097EE346D63}"  
   ; FOLDERID_Cookies                 := "{2B0F765D-C0E9-4171-908E-08A611B84FF6}"  
   ; FOLDERID_Desktop                 := "{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"  
   ; FOLDERID_DeviceMetadataStore     := "{5CE4A5E9-E4EB-479D-B89F-130C02886155}" ; Windows  7
   ; FOLDERID_Documents               := "{FDD39AD0-238F-46AF-ADB4-6C85480369C7}"  
   ; FOLDERID_DocumentsLibrary        := "{7B0DB17D-9CD2-4A93-9733-46CC89022E7C}" ; Windows  7
   ; FOLDERID_Downloads               := "{374DE290-123F-4565-9164-39C4925E467B}"  
   ; FOLDERID_Favorites               := "{1777F761-68AD-4D8A-87BD-30B759FA33DD}"  
   ; FOLDERID_Fonts                   := "{FD228CB7-AE11-4AE3-864C-16F3910AB8FE}"  
   ; FOLDERID_Games                   := "{CAC52C1A-B53D-4edc-92D7-6B2E8AC19434}"  
   ; FOLDERID_GameTasks               := "{054FAE61-4DD8-4787-80B6-090220C4B700}" ; Windows  Vista
   ; FOLDERID_History                 := "{D9DC8A3B-B784-432E-A781-5A1130A75963}"  
   ; FOLDERID_HomeGroup               := "{52528A6B-B9E3-4ADD-B60D-588C2DBA842D}" ; Windows  7
   ; FOLDERID_HomeGroupCurrentUser    := "{9B74B6A3-0DFD-4f11-9E78-5F7800F2E772}" ; Windows  8
   ; FOLDERID_ImplicitAppShortcuts    := "{BCB5256F-79F6-4CEE-B725-DC34E402FD46}" ; Windows  7
   ; FOLDERID_InternetCache           := "{352481E8-33BE-4251-BA85-6007CAEDCF9D}"  
   ; FOLDERID_InternetFolder          := "{4D9F7874-4E0C-4904-967B-40B0D20C3E4B}"  
   ; FOLDERID_Libraries               := "{1B3EA5DC-B587-4786-B4EF-BD1DC332AEAE}" ; Windows  7
   ; FOLDERID_Links                   := "{bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968}"  
   ; FOLDERID_LocalAppData            := "{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}"  
   ; FOLDERID_LocalAppDataLow         := "{A520A1A4-1780-4FF6-BD18-167343C5AF16}"  
   ; FOLDERID_LocalizedResourcesDir   := "{2A00375E-224C-49DE-B8D1-440DF7EF3DDC}"  
   ; FOLDERID_Music                   := "{4BD8D571-6D19-48D3-BE97-422220080E43}"  
   ; FOLDERID_MusicLibrary            := "{2112AB0A-C86A-4FFE-A368-0DE96E47012E}" ; Windows  7
   ; FOLDERID_NetHood                 := "{C5ABBF53-E17F-4121-8900-86626FC2C973}"  
   ; FOLDERID_NetworkFolder           := "{D20BEEC4-5CA8-4905-AE3B-BF251EA09B53}"  
   ; FOLDERID_Objects3D               := "{31C0DD25-9439-4F12-BF41-7FF4EDA38722}" ; Windows  10, version 1703
   ; FOLDERID_OriginalImages          := "{2C36C0AA-5812-4b87-BFD0-4CD0DFB19B39}" ; Windows  Vista
   ; FOLDERID_PhotoAlbums             := "{69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C}" ; Windows  Vista
   ; FOLDERID_PicturesLibrary         := "{A990AE9F-A03B-4E80-94BC-9912D7504104}" ; Windows  7
   ; FOLDERID_Pictures                := "{33E28130-4E1E-4676-835A-98395C3BC3BB}"  
   ; FOLDERID_Playlists               := "{DE92C1C7-837F-4F69-A3BB-86E631204A23}"  
   ; FOLDERID_PrintersFolder          := "{76FC4E2D-D6AD-4519-A663-37BD56068185}"  
   ; FOLDERID_PrintHood               := "{9274BD8D-CFD1-41C3-B35E-B13F55A758F4}"  
   ; FOLDERID_Profile                 := "{5E6C858F-0E22-4760-9AFE-EA3317B67173}"  
   ; FOLDERID_ProgramData             := "{62AB5D82-FDC1-4DC3-A9DD-070D1D495D97}"  
   ; FOLDERID_ProgramFiles            := "{905e63b6-c1bf-494e-b29c-65b732d3d21a}"  
   ; FOLDERID_ProgramFilesX64         := "{6D809377-6AF0-444b-8957-A3773F02200E}"  
   ; FOLDERID_ProgramFilesX86         := "{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}"  
   ; FOLDERID_ProgramFilesCommon      := "{F7F1ED05-9F6D-47A2-AAAE-29D317C6F066}"  
   ; FOLDERID_ProgramFilesCommonX64   := "{6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D}"  
   ; FOLDERID_ProgramFilesCommonX86   := "{DE974D24-D9C6-4D3E-BF91-F4455120B917}"  
   ; FOLDERID_Programs                := "{A77F5D77-2E2B-44C3-A6A2-ABA601054A51}"  
   ; FOLDERID_Public                  := "{DFDF76A2-C82A-4D63-906A-5644AC457385}"  
   ; FOLDERID_PublicDesktop           := "{C4AA340D-F20F-4863-AFEF-F87EF2E6BA25}"  
   ; FOLDERID_PublicDocuments         := "{ED4824AF-DCE4-45A8-81E2-FC7965083634}"  
   ; FOLDERID_PublicDownloads         := "{3D644C9B-1FB8-4f30-9B45-F670235F79C0}" ; Windows  Vista
   ; FOLDERID_PublicGameTasks         := "{DEBF2536-E1A8-4c59-B6A2-414586476AEA}" ; Windows  Vista
   ; FOLDERID_PublicLibraries         := "{48DAF80B-E6CF-4F4E-B800-0E69D84EE384}" ; Windows  7
   ; FOLDERID_PublicMusic             := "{3214FAB5-9757-4298-BB61-92A9DEAA44FF}"  
   ; FOLDERID_PublicPictures          := "{B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5}"  
   ; FOLDERID_PublicRingtones         := "{E555AB60-153B-4D17-9F04-A5FE99FC15EC}" ; Windows  7
   ; FOLDERID_PublicUserTiles         := "{0482af6c-08f1-4c34-8c90-e17ec98b1e17}" ; Windows  8
   ; FOLDERID_PublicVideos            := "{2400183A-6185-49FB-A2D8-4A392A602BA3}"  
   ; FOLDERID_QuickLaunch             := "{52a4f021-7b75-48a9-9f6b-4b87a210bc8f}"  
   ; FOLDERID_Recent                  := "{AE50C081-EBD2-438A-8655-8A092E34987A}"  
   ; FOLDERID_RecordedTV              := "{1A6FDBA2-F42D-4358-A798-B74D745926C5}" ; Windows  7
   ; FOLDERID_RecycleBinFolder        := "{B7534046-3ECB-4C18-BE4E-64CD4CB7D6AC}"  
   ; FOLDERID_ResourceDir             := "{8AD10C31-2ADB-4296-A8F7-E4701232C972}"  
   ; FOLDERID_Ringtones               := "{C870044B-F49E-4126-A9C3-B52A1FF411E8}" ; Windows  7
   ; FOLDERID_RoamingAppData          := "{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D}"  
   ; FOLDERID_RoamedTileImages        := "{AAA8D5A5-F1D6-4259-BAA8-78E7EF60835E}" ; Windows  8
   ; FOLDERID_RoamingTiles            := "{00BCFC5A-ED94-4e48-96A1-3F6217F21990}" ; Windows  8
   ; FOLDERID_SampleMusic             := "{B250C668-F57D-4EE1-A63C-290EE7D1AA1F}"  
   ; FOLDERID_SamplePictures          := "{C4900540-2379-4C75-844B-64E6FAF8716B}"  
   ; FOLDERID_SamplePlaylists         := "{15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5}" ; Windows  Vista
   ; FOLDERID_SampleVideos            := "{859EAD94-2E85-48AD-A71A-0969CB56A6CD}"  
   ; FOLDERID_SavedGames              := "{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}" ; Windows  Vista
   ; FOLDERID_SavedPictures           := "{3B193882-D3AD-4eab-965A-69829D1FB59F}"  
   ; FOLDERID_SavedPicturesLibrary    := "{E25B5812-BE88-4bd9-94B0-29233477B6C3}"  
   ; FOLDERID_SavedSearches           := "{7d1d3a04-debb-4115-95cf-2f29da2920da}"  
   ; FOLDERID_Screenshots             := "{b7bede81-df94-4682-a7d8-57a52620b86f}" ; Windows  8
   ; FOLDERID_SEARCH_CSC              := "{ee32e446-31ca-4aba-814f-a5ebd2fd6d5e}"  
   ; FOLDERID_SearchHistory           := "{0D4C3DB6-03A3-462F-A0E6-08924C41B5D4}" ; Windows  8.1
   ; FOLDERID_SearchHome              := "{190337d1-b8ca-4121-a639-6d472d16972a}"  
   ; FOLDERID_SEARCH_MAPI             := "{98ec0e18-2098-4d44-8644-66979315a281}"  
   ; FOLDERID_SearchTemplates         := "{7E636BFE-DFA9-4D5E-B456-D7B39851D8A9}" ; Windows  8.1
   ; FOLDERID_SendTo                  := "{8983036C-27C0-404B-8F08-102D10DCFD74}"  
   ; FOLDERID_SidebarDefaultParts     := "{7B396E54-9EC5-4300-BE0A-2482EBAE1A26}"  
   ; FOLDERID_SidebarParts            := "{A75D362E-50FC-4fb7-AC2C-A8BEAA314493}"  
   ; FOLDERID_SkyDrive                := "{A52BBA46-E9E1-435f-B3D9-28DAA648C0F6}" ; Windows  8.1
   ; FOLDERID_SkyDriveCameraRoll      := "{767E6811-49CB-4273-87C2-20F355E1085B}" ; Windows  8.1
   ; FOLDERID_SkyDriveDocuments       := "{24D89E24-2F19-4534-9DDE-6A6671FBB8FE}" ; Windows  8.1
   ; FOLDERID_SkyDrivePictures        := "{339719B5-8C47-4894-94C2-D8F77ADD44A6}" ; Windows  8.1
   ; FOLDERID_StartMenu               := "{625B53C3-AB48-4EC1-BA1F-A1EF4146FC19}"  
   ; FOLDERID_Startup                 := "{B97D20BB-F46A-4C97-BA10-5E3608430854}"  
   ; FOLDERID_SyncManagerFolder       := "{43668BF8-C14E-49B2-97C9-747784D784B7}" ; Windows  Vista
   ; FOLDERID_SyncResultsFolder       := "{289a9a43-be44-4057-a41b-587a76d7e7f9}" ; Windows  Vista
   ; FOLDERID_SyncSetupFolder         := "{0F214138-B1D3-4a90-BBA9-27CBC0C5389A}" ; Windows  Vista
   ; FOLDERID_System                  := "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}"  
   ; FOLDERID_SystemX86               := "{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27}"  
   ; FOLDERID_Templates               := "{A63293E8-664E-48DB-A079-DF759E0509F7}"  
   ; FOLDERID_TreeProperties          := "{9E3995AB-1F9C-4F13-B827-48B24B6C7174}" ; Windows  7
   ; FOLDERID_UserProfiles            := "{0762D272-C50A-4BB0-A382-697DCD729B80}"  
   ; FOLDERID_UserProgramFiles        := "{5CD7AEE2-2219-4A67-B85D-6C9CE15660CB}" ; Windows  7
   ; FOLDERID_UserProgramFilesCommon  := "{BCBD3057-CA5C-4622-B42D-BC56DB0AE516}" ; Windows  7
   ; FOLDERID_UsersFiles              := "{f3ce0f7c-4901-4acc-8648-d5d44b04ef8f}"  
   ; FOLDERID_UsersLibraries          := "{A302545D-DEFF-464b-ABE8-61C8648D939B}" ; Windows  7
   ; FOLDERID_Videos                  := "{18989B1D-99B5-455B-841C-AB7C74E4DDFC}"  
   ; FOLDERID_VideosLibrary           := "{491E922F-5643-4AF4-A7EB-4E7A138D8174}" ; Windows  7
   ; FOLDERID_Windows                 := "{F38BF404-1D43-42F2-9305-67DE0B28FC23}"  
   ; function by Skan: https://www.autohotkey.com/boards/viewtopic.php?f=6&t=75602&sid=f29192e2e8a74e847f62a152afa55aa1
   Local CLSID, pPath:=""                                        ; Thanks teadrinker @ tiny.cc/p286094
   Return Format("{4:}", VarSetCapacity(CLSID, 16, 0)
        , DllCall("ole32\CLSIDFromString", "Str",FOLDERID, "Ptr",&CLSID)
        , DllCall("shell32\SHGetKnownFolderPath", "Ptr",&CLSID, "UInt",KF_FLAG, "Ptr",0, "PtrP",pPath)
        , StrGet(pPath, "utf-16")
        , DllCall("ole32\CoTaskMemFree", "Ptr",pPath))

}

ShellFileOperation(fileO, fSource, fTarget, flags, ghwnd:=0x0) {
/*
   Provides access to Windows built-in file operation system 
   (move / copy / rename / delete files or folders with the standard Windows dialog and error UI).  
   Utilizes the SHFileOperation shell function in Windows.

   For online documentation [broken link]
   See http://www.autohotkey.net/~Rapte_Of_Suzaku/Documentation/files/ShellFileOperation-ahk.html

   Function found on: https://github.com/denolfe/AutoHotkey/blob/master/lib/ShellFileOperation.ahk
   Release #3
   Joshua A. Kinnison
   2010-09-29, 15:12
*/
; modified by Marius Șucan

   ; AVAILABLE OPERATIONS [fileO]
   static FO_MOVE                   := 0x1
   static FO_COPY                   := 0x2
   static FO_DELETE                 := 0x3
   static FO_RENAME                 := 0x4

   ; AVAILABLE FLAGS
   static FOF_MULTIDESTFILES        := 0x1     ; Indicates that the to member specifies multiple destination files (one for each source file) rather than one directory where all source files are to be deposited.
   static FOF_CONFIRMMOUSE          := 0x2     ; ???
   static FOF_SILENT                := 0x4     ; Does not display a progress dialog box.
   static FOF_RENAMEONCOLLISION     := 0x8     ; Gives the file being operated on a new name (such as "Copy #1 of...") in a move, copy, or rename operation if a file of the target name already exists.
   static FOF_NOCONFIRMATION        := 0x10    ; Responds with "yes to all" for any dialog box that is displayed.
   static FOF_WANTMAPPINGHANDLE     := 0x20    ; returns info about the actual result of the operation
   static FOF_ALLOWUNDO             := 0x40    ; Preserves undo information, if possible. With del, uses recycle bin.
   static FOF_FILESONLY             := 0x80    ; Performs the operation only on files if a wildcard filename (*.*) is specified.
   static FOF_SIMPLEPROGRESS        := 0x100   ; Displays a progress dialog box, but does not show the filenames.
   static FOF_NOCONFIRMMKDIR        := 0x200   ; Does not confirm the creation of a new directory if the operation requires one to be created.
   static FOF_NOERRORUI             := 0x400   ; don't put up error UI
   static FOF_NOCOPYSECURITYATTRIBS := 0x800   ; dont copy file security attributes
   static FOF_NORECURSION           := 0x1000  ; Only operate in the specified directory. Don't operate recursively into subdirectories.
   static FOF_NO_CONNECTED_ELEMENTS := 0x2000  ; Do not move connected files as a group (e.g. html file together with images). Only move the specified files.
   static FOF_WANTNUKEWARNING       := 0x4000  ; Send a warning if a file is being destroyed during a delete operation rather than recycled. This flag partially overrides FOF_NOCONFIRMATION.
   static FOF_NORECURSEREPARSE      := 0x8000  ; treat reparse points as objects, not containers ?

   If !fSource
   {
      ret := []
      Return ret["error"] := -1
   }

   fileO := %fileO% ? %fileO% : fileO
   If (SubStr(flags, 0)="|")
      flags := SubStr(flags,1,-1)

   _flags := 0
   Loop Parse, flags, |
      _flags |= %A_LoopField%   

   flags := _flags ? _flags : (%flags% ? %flags% : flags)
   If (SubStr(fSource, 0)!= "|" )
      fSource := fSource . "|"

   If (SubStr(fTarget, 0)!="|")
      fTarget := fTarget . "|"
   
   char_size := A_IsUnicode ? 2 : 1
   char_type := A_IsUnicode ? "UShort" : "Char"
   
   fsPtr := &fSource
   Loop % StrLen(fSource)
   {
      if (NumGet(fSource, (A_Index-1)*char_size, char_type) = 124)
         NumPut(0, fSource, (A_Index-1)*char_size, char_type)
   }

   ftPtr := &fTarget
   Loop % StrLen(fTarget)
   {
      if (NumGet(fTarget, (A_Index-1)*char_size, char_type) = 124)
         NumPut(0, fTarget, (A_Index-1)*char_size, char_type)
   }
   
   VarSetCapacity(SHFILEOPSTRUCT, 60, 0)                  ; Encoding SHFILEOPSTRUCT
   NextOffset := NumPut(ghwnd, &SHFILEOPSTRUCT )          ; hWnd of calling GUI
   NextOffset := NumPut(fileO, NextOffset+0    )          ; File operation
   NextOffset := NumPut(fsPtr, NextOffset+0    )          ; Source file / pattern
   NextOffset := NumPut(ftPtr, NextOffset+0    )          ; Target file / folder
   NextOffset := NumPut(flags, NextOffset+0, 0, "Short")  ; options

   code    := DllCall("Shell32\SHFileOperationW", "UPtr", &SHFILEOPSTRUCT)
   aborted := NumGet(NextOffset+0)
   H2M_ptr := NumGet(NextOffset+4)
   
   ret              := []
   ret["mappings"]  := []
   ret["error"]     := code
   ret["aborted"]   := aborted

   if (FOF_WANTMAPPINGHANDLE & flags)
   {
      ; HANDLETOMAPPINGS 
      ret["num_mappings"]  := NumGet(H2M_ptr+0)
      map_ptr              := NumGet(H2M_ptr+4)
      
      Loop % ret["num_mappings"]
      {
         ; _SHNAMEMAPPING
         addr := map_ptr+(A_Index-1)*16 ;
         old  := StrGet(NumGet(addr+0))
         new  := StrGet(NumGet(addr+4))
         
         ret["mappings"][old] := new
      }
   }
   
   ; free mappings handle if it was requested
   if (FOF_WANTMAPPINGHANDLE & flags)
      DllCall("Shell32\SHFreeNameMappings", int, H2M_ptr)
   
   Return ret
}

invokeSHopenWith(givenFile) {
; function by zcooler
; source:  https://www.autohotkey.com/boards/viewtopic.php?t=17850

  ; msdn.microsoft.com/en-us/library/windows/desktop/bb762234(v=vs.85).aspx
  ; OAIF_ALLOW_REGISTRATION   0x00000001 - Enable the "always use this program" checkbox. If not passed, it will be disabled.
  ; OAIF_REGISTER_EXT         0x00000002 - Do the registration after the user hits the OK button.
  ; OAIF_EXEC                 0x00000004 - Execute file after registering.
  VarSetCapacity(OPENASINFO, A_PtrSize * 3, 0)
  NumPut(&givenFile, OPENASINFO, 0, "Ptr")
  NumPut(0x04, OPENASINFO, A_PtrSize * 2, "UInt") ; OAIF_EXEC
  DllCall("Shell32.dll\SHOpenWithDialog", "Ptr", 0, "Ptr", &OPENASINFO)
}

; ==================================================================================================================================
; function by «just me», source https://www.autohotkey.com/boards/viewtopic.php?t=18081
;
; Creates an 'open with' menu for the passed file.
; Parameters:
;     FilePath    -  Fully qualified path of a single file.
;     Recommended -  Show only recommended apps (True/False).
;                    Default: True
;     ShowMenu    -  Immediately show the menu (True/False).
;                    Default: False
;     MenuName    -  The name of the menu.
;                    Default: OpenWithMenu
;     Others      -  Name of the submenu holding not recommended apps (if Recommended has been set to False).
;                    Default: Others
; Return values:
;     On success the function returns the menu's name unless ShowMenu has been set to True.
;     If the menu couldn't be created, the function returns False.
; Remarks:
;     Requires AHK 1.1.23.07+ and Win Vista+!!!
;     The function registers itself as the menu handler.
; Credits:
;     Based on code by querty12 -> autohotkey.com/boards/viewtopic.php?p=86709#p86709.
;     I hadn't even heard anything about the related API functions before.
; MSDN:
;     SHAssocEnumHandlers -> msdn.microsoft.com/en-us/library/bb762109%28v=vs.85%29.aspx
;     SHCreateItemFromParsingName -> msdn.microsoft.com/en-us/library/bb762134%28v=vs.85%29.aspx
; ==================================================================================================================================
CreateOpenWithMenu(FilePath, Recommended := 1, ShowMenu := 0, MenuName := "OpenWithMenu", Others := "Others") {
   Static RecommendedHandlers := []
        , OtherHandlers := []
        , HandlerID := A_TickCount
        , HandlerFunc := 0
        , ThisMenuName := ""
        , ThisOthers := ""
   ; -------------------------------------------------------------------------------------------------------------------------------
   Static IID_IShellItem := 0, BHID_DataObject := 0, IID_IDataObject := 0
        , Init := 0

   If !init
   {
      init := 1
      VarSetCapacity(IID_IShellItem, 16, 0)
      VarSetCapacity(BHID_DataObject, 16, 0)
      VarSetCapacity(IID_IDataObject, 16, 0)
      DllCall("Ole32.dll\IIDFromString", "WStr", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}", "Ptr", &IID_IShellItem)
      DllCall("Ole32.dll\IIDFromString", "WStr", "{B8C0BD9F-ED24-455c-83E6-D5390C4FE8C4}", "Ptr", &BHID_DataObject)
      DllCall("Ole32.dll\IIDFromString", "WStr", "{0000010e-0000-0000-C000-000000000046}", "Ptr", &IID_IDataObject)
   }

   ; -------------------------------------------------------------------------------------------------------------------------------
   ; Handler call
   If (Recommended = HandlerID) {
      AssocHandlers := A_ThisMenu = ThisMenuName ? RecommendedHandlers : OtherHandlers
      If (AssocHandler := AssocHandlers[A_ThisMenuItemPos]) && FileExist(FilePath) {
         AssocHandlerInvoke := NumGet(NumGet(AssocHandler + 0, "UPtr"), A_PtrSize * 8, "UPtr")
         If !DllCall("Shell32.dll\SHCreateItemFromParsingName", "WStr", FilePath, "Ptr", 0, "Ptr", &IID_IShellItem, "PtrP", Item) {
            BindToHandler := NumGet(NumGet(Item + 0, "UPtr"), A_PtrSize * 3, "UPtr")
            If !DllCall(BindToHandler, "Ptr", Item, "Ptr", 0, "Ptr", &BHID_DataObject, "Ptr", &IID_IDataObject, "PtrP", DataObj) {
               DllCall(AssocHandlerInvoke, "Ptr", AssocHandler, "Ptr", DataObj)
               ObjRelease(DataObj)
            }
            ObjRelease(Item)
         }
      }
      Try Menu, %ThisMenuName%, DeleteAll
      For Each, AssocHandler In RecommendedHandlers
         ObjRelease(AssocHandler)
      For Each, AssocHandler In OtherHandlers
         ObjRelease(AssocHandler)
      RecommendedHandlers := []
      OtherHandlers := []
      Return
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   ; User call
   If !FileExist(FilePath)
      Return 0

   ThisMenuName := MenuName
   ThisOthers := Others
   SplitPath, FilePath, , , Ext
   For Each, AssocHandler In RecommendedHandlers
      ObjRelease(AssocHandler)
   For Each, AssocHandler In OtherHandlers
      ObjRelease(AssocHandler)
   RecommendedHandlers:= []
   OtherHandlers:= []
   Try Menu, %ThisMenuName%, DeleteAll
   Try Menu, %ThisOthers%, DeleteAll
   ; Try to get the default association
   Size := VarSetCapacity(FriendlyName, 520, 0) // 2
   DllCall("Shlwapi.dll\AssocQueryString", "UInt", 0, "UInt", 4, "Str", "." . Ext, "Ptr", 0, "Str", FriendlyName, "UIntP", Size)
   HandlerID := A_TickCount
   HandlerFunc := Func(A_ThisFunc).Bind(FilePath, HandlerID)
   Filter := !!Recommended ; ASSOC_FILTER_NONE = 0, ASSOC_FILTER_RECOMMENDED = 1
   ; Enumerate the apps and build the menu
   If DllCall("Shell32.dll\SHAssocEnumHandlers", "WStr", "." . Ext, "UInt", Filter, "PtrP", EnumHandler)
      Return 0

   EnumHandlerNext := NumGet(NumGet(EnumHandler + 0, "UPtr"), A_PtrSize * 3, "UPtr")
   While (!DllCall(EnumHandlerNext, "Ptr", EnumHandler, "UInt", 1, "PtrP", AssocHandler, "UIntP", Fetched) && Fetched)
   {
      VTBL := NumGet(AssocHandler + 0, "UPtr")
      AssocHandlerGetUIName := NumGet(VTBL + 0, A_PtrSize * 4, "UPtr")
      AssocHandlerGetIconLocation := NumGet(VTBL + 0, A_PtrSize * 5, "UPtr")
      AssocHandlerIsRecommended := NumGet(VTBL + 0, A_PtrSize * 6, "UPtr")
      UIName := ""
      If !DllCall(AssocHandlerGetUIName, "Ptr", AssocHandler, "PtrP", StrPtr, "UInt")
      {
         UIName := StrGet(StrPtr, "UTF-16")
         DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
      } Else UIName := AssocHandler

      If (UIName!="")
      {
         If !DllCall(AssocHandlerGetIconLocation, "Ptr", AssocHandler, "PtrP", StrPtr, "IntP", IconIndex := 0, "UInt")
         {
            IconPath := StrGet(StrPtr, "UTF-16")
            DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
         }

         If (SubStr(IconPath, 1, 1) = "@")
         {
            VarSetCapacity(Resource, 4096, 0)
            If !DllCall("Shlwapi.dll\SHLoadIndirectString", "WStr", IconPath, "Ptr", &Resource, "UInt", 2048, "PtrP", 0)
               IconPath := StrGet(&Resource, "UTF-16")
         }
         ItemName := StrReplace(UIName, "&", "&&")
         If (Recommended || !DllCall(AssocHandlerIsRecommended, "Ptr", AssocHandler, "UInt"))
         {
            If (UIName=FriendlyName)
            {
               If RecommendedHandlers.Count()
               {
                  Menu, %ThisMenuName%, Insert, 1&, %ItemName%, % HandlerFunc
                  RecommendedHandlers.InsertAt(1, AssocHandler)
               } Else
               {
                  Menu, %ThisMenuName%, Add, %ItemName%, % HandlerFunc
                  RecommendedHandlers.Push(AssocHandler)
               }
         ;      Menu, %ThisMenuName%, Default, %ItemName%
            } Else
            {
               Menu, %ThisMenuName%, Add, %ItemName%, % HandlerFunc
               RecommendedHandlers.Push(AssocHandler)
            }
            Try Menu, %ThisMenuName%, Icon, %ItemName%, %IconPath%, %IconIndex%
         } Else
         {
            Menu, %ThisOthers%, Add, %ItemName%, % HandlerFunc
            OtherHandlers.Push(AssocHandler)
            Try Menu, %ThisOthers%, Icon, %ItemName%, %IconPath%, %IconIndex%
         }
      } Else ObjRelease(AssocHandler)
   }

   ObjRelease(EnumHandler)
   ; All done
   If !RecommendedHandlers.Count() && !OtherHandlers.Count()
      Return 0

   If OtherHandlers.Count()
      Menu, %ThisMenuName%, Add, %ThisOthers%, :%ThisOthers%

   If (ShowMenu=1)
      Menu, %ThisMenuName%, Show
   Else
      Return ThisMenuName
}

; =================================================================================================
; Function......: GetModuleFileNameEx
; DLL...........: Kernel32.dll / Psapi.dll
; Library.......: Kernel32.lib / Psapi.lib
; U/ANSI........: GetModuleFileNameExW (Unicode) and GetModuleFileNameExA (ANSI)
; Author........: jNizM
; Modified......:
; Links.........: http://msdn.microsoft.com/en-us/library/windows/desktop/ms683198(v=vs.85).aspx
; =================================================================================================

GetModuleFileNameEx(PID) {
; found on: https://autohotkey.com/board/topic/109557-processid-a-scriptfullpath/

    hProcess := DllCall("Kernel32.dll\OpenProcess", "UInt", 0x001F0FFF, "UInt", 0, "UInt", PID)
    If (ErrorLevel || hProcess = 0)
       Return
    Static lpFilename, nSize := 2260, int := VarSetCapacity(lpFilename, nSize, 0)
    DllCall("Psapi.dll\GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", lpFilename, "UInt", nSize)
    DllCall("Kernel32.dll\CloseHandle", "Ptr", hProcess)
    Return lpFilename
}

GetCurrentProcessId() {
    Return DllCall("Kernel32.dll\GetCurrentProcessId")
}

RunAdminMode() {
  If !A_IsAdmin
  {
      pid :=GetCurrentProcessId()
      path2exe := GetModuleFileNameEx(pid)
      Try {
         If A_IsCompiled
            Run *RunAs "%path2exe%" /restart
         Else
            Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"

         ExitApp
      } Catch, err

      If (err && !AnyWindowOpen)
         msgBoxWrapper(appTitle ": ERROR", "An unknown error occured trying to restart in admin mode.`n" err, 0, 0, "error")
   }
}

SetVolume(val:=100, r:="") {
; Function by Drugwash
  v := Round(val*655.35)
  vr := r="" ? v : Round(r*655.35)
  Try DllCall("winmm\waveOutSetVolume", "UInt", 0, "UInt", (v|vr<<16))
}

ShellFileAssociate(Label,Ext,Cmd,batchMode,storePath) {
  Static q := Chr(34)  ; the quotes symbol
  ; by Ħakito: https://autohotkey.com/boards/viewtopic.php?f=6&t=55638 
  ; modified by Marius Șucan

  ; Weeds out faulty extensions, which must start with a period, and contain more than 1 character
  IF (SubStr(Ext,1,1)!="." || StrLen(Ext)<=1)
     Return 0

  ; Weeds out faulty labels such as ".exe" which is an extension and not a label
  IF (SubStr(Label,1,1)=".")
     Return 0

  If Label
     RegRead, CheckLabel, HKEY_CLASSES_ROOT\%Label%, FriendlyTypeName

  ; Do not allow the modification of some important registry labels
  iF (Cmd!="" && CheckLabel)
     Return 0

  regFile := "Windows Registry Editor Version 5.00`n`n"
  ; Note that "HKEY_CLASSES_ROOT" actually writes to "HKEY_LOCAL_MACHINE\SOFTWARE\Classes"
  ; If the command is just a simple path, then convert it into a proper run command
  iF (SubStr(Cmd,2,2)=":\" && FileExist(Cmd))
     Cmd := q Cmd q A_Space q "%1" q
  Else
     Return 0

  Cmd := StrReplace(Cmd, "\", "\\")
  Cmd := StrReplace(Cmd, """", "\""")
  typeInfo := "`n""ContentType""=" q "image/" Ext q "`n""PerceivedType""=" q "image" q "`n"
  regFile .= "[HKEY_CLASSES_ROOT\" Ext "]`n@=" q Label q typeInfo
  regFile .= "`n[HKEY_CLASSES_ROOT\" Label "]`n@=" q Label q "`n"
  regFile .= "`n[HKEY_CLASSES_ROOT\" Label "\Shell\Open\Command]`n@=" q Cmd q "`n"

  regFile .= "`n[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\" Ext "]`n@=" q Label q typeInfo
  regFile .= "`n[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\" Label "]`n@=" q Label q "`n"
  regFile .= "`n[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\" Label "\Shell\Open\Command]`n@=" q Cmd q "`n"

  regFile .= "`n[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\" Ext "\UserChoice]`n""ProgId""=" q Label q "`n"
  regFile .= "`n[-HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\" Ext "\OpenWithProgids]`n"
  regFile .= "`n[-HKEY_CLASSES_ROOT\" Ext "\OpenWithProgids]`n`n"

  If !FolderExist(storePath "\regFiles")
  {
     FileCreateDir, %storePath%\regFiles
     If ErrorLevel
        Return 0

     Sleep, 1
  }

  iExt := StrReplace(Ext, ".")
  FileDelete, %storePath%\regFiles\RegFormat%iExt%.reg
  Sleep, 1
  FileAppend, % regFile, %storePath%\regFiles\RegFormat%iExt%.reg, UTF-16
  If ErrorLevel
     Return 0

  runTarget := "Reg Import " q storePath "\regFiles\RegFormat" iExt ".reg" q "`n"
  If !InStr("|WIN_7|WIN_8|WIN_8.1|WIN_VISTA|WIN_2003|WIN_XP|WIN_2000|", "|" A_OSVersion "|")
     runTarget .= q storePath "\SetUserFTA.exe" q A_Space Ext A_Space Label "`n"

  FileAppend, % runTarget, %storePath%\regFiles\runThis.bat
  If ErrorLevel
     Return 0

  If (batchMode!=1)
  {
     Sleep, 1
     Try RunWait, *RunAs "%storePath%\regFiles\runThis.bat"
     Sleep, 1
     FileDelete, %storePath%\regFiles\RegFormat%iExt%.reg
     FileDelete, %storePath%\regFiles\runThis.bat
  }

  Return 1
}

GetRes(ByRef bin, lib, res, type) {
  If !A_IsCompiled
     Return 0

  hL := 0
  If lib
     hM := DllCall("kernel32\GetModuleHandleW", "Str", lib, "Ptr")

  If !lib
  {
     hM := 0  ; current module
  } Else If !hM
  {
     If (!hL := hM := DllCall("kernel32\LoadLibraryW", "Str", lib, "Ptr"))
        Return
  }

  dt := (type+0 != "") ? "UInt" : "Str"
  hR := DllCall("kernel32\FindResourceW"
      , "Ptr" , hM
      , "Str" , res
      , dt , type
      , "Ptr")

  If !hR
  {
     fnOutputDebug("GetRes() ERR " FormatMessage(A_ThisFunc "(" lib ", " res ", " type ", " l ")", A_LastError))
     Return
  }

  hD := DllCall("kernel32\LoadResource"
      , "Ptr" , hM
      , "Ptr" , hR
      , "Ptr")
  hB := DllCall("kernel32\LockResource"
      , "Ptr" , hD
      , "Ptr")
  sz := DllCall("kernel32\SizeofResource"
      , "Ptr" , hM
      , "Ptr" , hR
      , "UInt")
  If !sz
  {
     fnOutputDebug("Error: resource size 0 in  " A_ThisFunc " ( " lib " ,  " res " ,  " type " )")
     DllCall("kernel32\FreeResource", "Ptr" , hD)
     If hL
        DllCall("kernel32\FreeLibrary", "Ptr", hL)
     Return
  }

  VarSetCapacity(bin, 0),     VarSetCapacity(bin, sz, 0)
  DllCall("ntdll\RtlMoveMemory", "Ptr", &bin, "Ptr", hB, "UInt", sz)
  DllCall("kernel32\FreeResource", "Ptr" , hD)

  If hL
     DllCall("kernel32\FreeLibrary", "Ptr", hL)

  Return sz
}

FormatMessage(ctx, msg, arg="") {
  Global
  Local txt, buf
  SetFormat, Integer, H
  msg+=0
  SetFormat, Integer, D
  frmMsg := DllCall("kernel32\FormatMessageW"
          , "UInt" , 0x1100 ; FORMAT_MESSAGE_FROM_SYSTEM/ALLOCATE_BUFFER
          , "Ptr"  , 0      ; lpSource
          , "UInt" , msg    ; dwMessageId
          , "UInt" , 0      ; dwLanguageId (0x0418=RO)
          , "PtrP" , buf    ; lpBuffer
          , "UInt" , 0      ; nSize
          , "Str"  , arg)   ; Arguments

  txt := StrGet(buf, "UTF-16")
  lF := DllCall("kernel32\LocalFree", "Ptr", buf)
  Result := "Error " msg " in " ctx ":`n" txt
  Return Result
}

GlobalMemoryStatusEx() {
; https://msdn.microsoft.com/en-us/library/aa366589(v=vs.85).aspx 
; by jNizM
; https://github.com/jNizM/MemoryInfo/blob/master/src/MemoryInfo.ahk
    static MSEX, init := NumPut(VarSetCapacity(MSEX, 64, 0), MSEX, "uint")
    if !(DllCall("GlobalMemoryStatusEx", "ptr", &MSEX))
       Return 0
       ;  throw Exception("Call to GlobalMemoryStatusEx failed: " A_LastError, -1)
    return { MemoryLoad: NumGet(MSEX, 4, "uint"), TotalPhys: NumGet(MSEX, 8, "uint64"), AvailPhys: NumGet(MSEX, 16, "uint64") }
}

GetProcessMemoryUsage(ProcessID) {
; by jNizM
; https://www.autohotkey.com/boards/viewtopic.php?t=62848
; modified by Marius Șucan

   static PMC_EX, size := NumPut(VarSetCapacity(PMC_EX, 8 + A_PtrSize * 9, 0), PMC_EX, "uint")

   if (hProcess := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", ProcessID))
   {
      if !(DllCall("GetProcessMemoryInfo", "ptr", hProcess, "ptr", &PMC_EX, "uint", size))
      {
         if !(DllCall("psapi\GetProcessMemoryInfo", "ptr", hProcess, "ptr", &PMC_EX, "uint", size))
            return (ErrorLevel := 2) & 0, DllCall("CloseHandle", "ptr", hProcess)
      }
      DllCall("CloseHandle", "ptr", hProcess)
      infos := []
      infos[0] := NumGet(PMC_EX, A_PtrSize, "uptr")   ; peak working set bytes
      infos[1] := NumGet(PMC_EX, 8 + A_PtrSize, "uptr")   ; working set bytes
      infos[8] := NumGet(PMC_EX, 8 + A_PtrSize*8, "uptr") ; private bytes
      Return infos
   }
   return (ErrorLevel := 1) & 0
}

Dlg_Color(clr, hwnd, cclrs) {
; Function by maestrith 
; clr must be RGB ; HEX [00-FF]
; cclrs - Custom colors must be an object 

; from: [AHK 1.1] Font and Color Dialogs 
; https://autohotkey.com/board/topic/94083-ahk-11-font-and-color-dialogs/
; Modified by Marius Șucan and Drugwash

  VarSetCapacity(CUSTOM, 64, 0)
  size := VarSetCapacity(CHOOSECOLOR, 9*A_PtrSize, 0)
  If IsObject(cclrs)
  {
     Loop, % cclrs.Count()
        NumPut(cclrs[A_Index], &CUSTOM, (A_Index-1)*4, "UInt")
  }

  clr := "0x00" clr
  clr := "0x" SubStr(clr, -1) SubStr(clr, 7, 2) SubStr(clr, 5, 2)
  NumPut(size,CHOOSECOLOR,0,"UInt")
  NumPut(hwnd,CHOOSECOLOR,A_PtrSize,"UPtr")
  NumPut(clr,CHOOSECOLOR,3*A_PtrSize,"UInt")
  NumPut(0x3,CHOOSECOLOR,5*A_PtrSize,"UInt")
  NumPut(&CUSTOM,CHOOSECOLOR,4*A_PtrSize,"UPtr")
  If (!ret := DllCall("comdlg32\ChooseColorW","UPtr",&CHOOSECOLOR,"UInt"))
     Return "-"

  Coloru := NumGet(CHOOSECOLOR,3*A_PtrSize,"UInt")
  Coloru := (Coloru & 0xFF00) + ((Coloru & 0xFF0000) >> 16) + ((Coloru & 0xFF) << 16)
  Coloru := Format("{:06X}", Coloru)
  CHOOSECOLOR := "",  CUSTOM := ""

  Return Coloru
}

Win_SetMenu(Hwnd, hMenu=0) {
   hPrevMenu := DllCall("GetMenu", "uint", hwnd, "Uint")
   DllCall("SetMenu", "uint", hwnd, "uint", hMenu)
   return hPrevMenu
}

SetMenuInfo(hMenu, maxHeight:=0, autoDismiss:=0, modeLess:=0, noCheck:=0) {
   cbSize := (A_PtrSize=8) ? 40 : 28
   VarSetCapacity(MENUINFO, cbSize, 0)
   fMaskFlags := 0x80000000         ; MIM_APPLYTOSUBMENUS
   cyMax := maxHeight ? maxHeight : 0
   If maxHeight
      fMaskFlags |= 0x00000001      ; MIM_MAXHEIGHT

   If (autoDismiss=1 || modeLess=1 || noCheck=1)
      fMaskFlags |= 0x00000010      ; MIM_STYLE

   dwStyle := 0
   If (autoDismiss=1)
      dwStyle |= 0x10000000         ; MNS_AUTODISMISS

   If (modeLess=1)
      dwStyle |= 0x40000000         ; MNS_MODELESS

   If (noCheck=1)
      dwStyle |= 0x80000000         ; MNS_NOCHECK

   NumPut(cbSize, MENUINFO, 0, "UInt") ; DWORD
   NumPut(fMaskFlags, MENUINFO, 4, "UInt") ; DWORD
   NumPut(dwStyle, MENUINFO, 8, "UInt") ; DWORD
   NumPut(cyMax, MENUINFO, 12, "UInt") ; UINT
   ; NumPut(hbrBack, MENUINFO, 16, "Ptr") ; HBRUSH
   ; NumPut(dwContextHelpID, MENUINFO, 20, "UInt") ; DWORD
   ; NumPut(dwMenuData, MENUINFO, 24, "UPtr") ; ULONG_PTR

   Return DllCall("User32\SetMenuInfo","Ptr", hMenu, "Ptr", &MENUINFO)
}







; ==================================================================
; Dlg_FontSelect() by TheArkive
; Parameters:
; fObj       = Initialize the dialog with specified values.
; hwnd       = Parent gui hwnd for modal, leave blank for not modal
; effects    = Allow selection of underline / strike out / italic
; ==================================================================
; fontObj output:
;
;    fontObj.str        = string to use with AutoHotkey to set GUI values - see examples
;    fontObj.size       = size of font
;    fontObj.name       = font name
;    fontObj.bold       = true/false
;    fontObj.italic     = true/false
;    fontObj.strike     = true/false
;    fontObj.underline  = true/false
;    fontObj.color      = RRGGBB
; ==================================================================
Dlg_FontSelect(fObj:="", hwnd:=0, Effects:=1) {
    Static _temp := {name:"", size:10, color:0, strike:0, underline:0, italic:0, bold:0}
    Static p := A_PtrSize, u := StrLen(Chr(0xFFFF)) ; u = IsUnicode
    
    fObj := (fObj="") ? _temp : fObj
    If (StrLen(fObj.name) > 31)
       return 0 ; throw Exception("Font name length exceeds 31 characters.")
    
    sz := (!u) ? 60 : (p=4) ? 92 : 96
    sz := VarSetCapacity(LOGFONT, sz, 0) ; LOGFONT size based on IsUnicode, not A_PtrSize
    hDC := Gdi_GetDC(0)
    LogPixels := Gdi_GetDeviceCaps(hDC, 90)
    Gdi_ReleaseDC(hDC)
  
    flags := 0x41 + (Effects ? 0x100 : 0) ; 0x41
    flags |= 0x1000     ; CF_NOSIMULATIONS
    flags |= 0x01000000 ; CF_NOVERTFONTS
    flags |= 0x1        ; CF_SCREENFONTS
    flags |= 0x40000    ; CF_TTONLY

    fObj.bold := fObj.bold ? 700 : 400
    fObj.size := Floor(fObj.size * LogPixels/72)

    NumPut(fObj.size,      LOGFONT,     "uint")
    NumPut(fObj.bold,      LOGFONT, 16, "uint")
    NumPut(fObj.italic,    LOGFONT, 20, "char")
    NumPut(fObj.underline, LOGFONT, 21, "char")
    NumPut(fObj.strike,    LOGFONT, 22, "char")
    StrPut(fObj.name,      &LOGFONT+28)

    color_convert := ((fObj.color & 0xFF) << 16 | fObj.color & 0xFF00 | fObj.color >> 16)
    sz := VarSetCapacity( CHOOSEFONT, (p=8) ? 104 : 60, 0)
    NumPut(sz,            CHOOSEFONT, 0,       "UInt")
    NumPut(hwnd+0,        CHOOSEFONT, p,       "UPtr")
    NumPut(&LOGFONT,      CHOOSEFONT, (p*3),   "UPtr")
    NumPut(flags,        CHOOSEFONT,  (p*4)+4, "UInt")
    NumPut(color_convert, CHOOSEFONT, (p*4)+8, "UInt")
    
    if !(r := DllCall("comdlg32\ChooseFont", "UPtr", &CHOOSEFONT)) ; Font Select Dialog opens
       return 0

    fObj.Name := StrGet(&LOGFONT+28)
    fObj.bold := ((b := NumGet(LOGFONT, 16, "UInt")) <= 400) ? 0 : 1
    fObj.italic := !!NumGet(LOGFONT, 20, "Char")
    fObj.underline := NumGet(LOGFONT, 21, "Char")
    fObj.strike := NumGet(LOGFONT, 22, "Char")
    fObj.size := Round(NumGet(CHOOSEFONT, p*4, "UInt") / 10)
    
    c := NumGet(CHOOSEFONT, (p=4) ? 6*p : 5*p, "UInt") ; convert from BGR to RBG for output
    fObj.color := Format("{:06X}", ((c & 0xFF) << 16 | c & 0xFF00 | c >> 16))

    str := ""
    str .= fObj.bold      ? "bold" : ""
    str .= fObj.italic    ? " italic" : ""
    str .= fObj.strike    ? " strike" : ""
    str .= fObj.color     ? " c" fObj.color : ""
    str .= fObj.size      ? " s" fObj.size : ""
    str .= fObj.underline ? " underline" : ""
    fObj.str := "norm " Trim(str)
    return fObj
}

CalcStringHash(string, algid, encoding = "UTF-8", byref hash = 0, byref hashlength = 0) {
; function by jNizM and Bentschi
; taken from https://github.com/jNizM/HashCalc
; this calculates the MD5 hash
; function under MIT License: https://raw.githubusercontent.com/jNizM/AHK_Network_Management/master/LICENSE

    chrlength := (encoding = "CP1200" || encoding = "UTF-16") ? 2 : 1
    length := (StrPut(string, encoding) - 1) * chrlength
    VarSetCapacity(data, length, 0)
    StrPut(string, &data, floor(length / chrlength), encoding)
    Result := CalcAddrHash(&data, length, algid, hash, hashlength)
    Return Result
}

CalcAddrHash(addr, length, algid, byref hash = 0, byref hashlength = 0) {
; function by jNizM and Bentschi
; taken from https://github.com/jNizM/HashCalc
; function under MIT License: https://raw.githubusercontent.com/jNizM/AHK_Network_Management/master/LICENSE

    Static h := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "a", "b", "c", "d", "e", "f"]
         , b := h.minIndex()
    hProv := hHash := o := ""
    CAC := DllCall("advapi32\CryptAcquireContext", "Ptr*", hProv, "Ptr", 0, "Ptr", 0, "UInt", 24, "UInt", 0xf0000000)
    If CAC
    {
       CCH := DllCall("advapi32\CryptCreateHash", "Ptr", hProv, "UInt", algid, "UInt", 0, "UInt", 0, "Ptr*", hHash)
       If CCH
       {
          CHD := DllCall("advapi32\CryptHashData", "Ptr", hHash, "Ptr", addr, "UInt", length, "UInt", 0)
          If CHD
          {
             CGP := DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", 0, "UInt*", hashlength, "UInt", 0)
             If CGP
             {
                VarSetCapacity(hash, hashlength, 0)
                CGHP := DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", &hash, "UInt*", hashlength, "UInt", 0)
                If CGHP
                {
                   Loop, %hashlength%
                   {
                      v := NumGet(hash, A_Index - 1, "UChar")
                      o .= h[(v >> 4) + b] h[(v & 0xf) + b]
                   }
                }
             }
          }
          CDH := DllCall("advapi32\CryptDestroyHash", "Ptr", hHash)
       }
       CRC := DllCall("advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
    }
    Return o
}

setMenusTheme(modus) {
   If (A_OSVersion="WIN_7" || A_OSVersion="WIN_XP")
      Return

   uxtheme := DllCall("GetModuleHandle", "str", "uxtheme", "uptr")
   SetPreferredAppMode := DllCall("GetProcAddress", "uptr", uxtheme, "ptr", 135, "uptr")
   global AllowDarkModeForWindow := DllCall("GetProcAddress", "uptr", uxtheme, "ptr", 133, "uptr")
   FlushMenuThemes := DllCall("GetProcAddress", "uptr", uxtheme, "ptr", 136, "uptr")
   DllCall(SetPreferredAppMode, "int", modus) ; Dark
   DllCall(FlushMenuThemes)
   interfaceThread.ahkPostFunction("setMenusTheme", modus)
}

setDarkWinAttribs(hwndGUI, modus:=2) {
   If (A_OSVersion="WIN_7" || A_OSVersion="WIN_XP")
      Return

   if (A_OSVersion >= "10.0.17763" && SubStr(A_OSVersion, 1, 4)>=10)
   {
       DWMWA_USE_IMMERSIVE_DARK_MODE := 19
       if (A_OSVersion >= "10.0.18985")
          DWMWA_USE_IMMERSIVE_DARK_MODE := 20
       DllCall("dwmapi\DwmSetWindowAttribute", "UPtr", hwndGUI, "int", DWMWA_USE_IMMERSIVE_DARK_MODE, "int*", modus, "int", 4)
   }
   DllCall(AllowDarkModeForWindow, "UPtr", hwndGUI, "int", modus) ; Dark
}

LinkUseDefaultColor(hLink, Use, whichGui) {
   VarSetCapacity(LITEM, 4278, 0)            ; 16 + (MAX_LINKID_TEXT * 2) + (L_MAX_URL_LENGTH * 2)
   NumPut(0x03, LITEM, "UInt")               ; LIF_ITEMINDEX (0x01) | LIF_STATE (0x02)
   NumPut(Use ? 0x10 : 0, LITEM, 8, "UInt")  ; ? LIS_DEFAULTCOLORS : 0
   NumPut(0x10, LITEM, 12, "UInt")           ; LIS_DEFAULTCOLORS
   While DllCall("SendMessage", "UPtr", hLink, "UInt", 0x0702, "Ptr", 0, "UPtr", &LITEM, "UInt") ; LM_SETITEM
         NumPut(A_Index, LITEM, 4, "Int")
   GuiControl, %whichGUI%: +Redraw, %hLink%
}

setPriorityThread(level, handle:="A") {
  If (handle="A" || !handle)
     handle := DllCall("GetCurrentThread")
  Return DllCall("SetThreadPriority", "UPtr", handle, "Int", level)
}

ConvertBase(InputBase, OutputBase, nptr){
    ; source https://www.autohotkey.com/boards/viewtopic.php?t=3925
    static u := A_IsUnicode ? "_wcstoui64" : "_strtoui64"
    static v := A_IsUnicode ? "_i64tow"    : "_i64toa"
    VarSetCapacity(s, 1024, 0)
    value := DllCall("msvcrt.dll\" u, "Str", nptr, "UInt", 0, "UInt", InputBase, "CDECL UInt64")
    DllCall("msvcrt.dll\" v, "UInt64", value, "Str", s, "UInt", OutputBase, "CDECL")
    ; ToolTip, % s , , , 2
    return s
}

GetScreenResInfos(disp:=0) {
; function by Masonjar13
; screenObj := GetScreenResInfos()
; msgbox % screenObj.w "x" screenObj.h "@" screenObj.hz ", orientation: " screenObj.o
; orientations:
; 0=landscape, 1=portrait, 2=landscape (flipped), 3=portrait (flipped)
    local dm,n:=varSetCapacity(dm,220,0)
    dllCall("EnumDisplaySettingsW",(disp=0?"Ptr":"WStr"),disp,"Int",-1,"Ptr",&dm)
    p := {w:numGet(dm,172,"UInt"),h:numGet(dm,176,"UInt"),hz:numGet(dm,184,"UInt"),o:numGet(dm,84,"UShort")}
    dm := 0
    return p
}

ChangeDisplaySettings(cD, sW, sH, rR, Perm="")   {
   ; By "just me" and "lexikos".
   ; Use 1 for Perm parameter to make the screen resolution change permanent so it stays after ExitApp.
   ; Otherwise the screen resolution will revert back when the program exits. The dafault.

   Static DM := {BITSPERPEL: 0x040000, PELSWIDTH: 0x080000, PELSHEIGHT: 0x100000, DISPLAYFREQUENCY: 0x400000}
   ; Calculate offset of DEVMODE fields:
   Static size := A_IsUnicode ? 220 : 156
   Static dmSize := A_IsUnicode ? 68 : 36 ; <<< has to be dmSize, not smSize
   Static dmFields := dmSize + 4
   Static dmBitsPerPel := A_IsUnicode ? 168 : 104
   Static dmPelsWidth := dmBitsPerPel + 4
   Static dmPelsHeight := dmPelsWidth + 4
   Static dmDisplayFrequency := dmPelsHeight + 8

   dmAddr := 0
   VarSetCapacity(DEVMODE, size, 0)
   NumPut(size, DEVMODE, dmSize, "UShort")
   fields := 0
   If (cD <> "") {
      NumPut(cD, DEVMODE, dmBitsPerPel, "UInt")
      fields |= DM.BITSPERPEL
   }
   If (sW <> "") {
      NumPut(sW, DEVMODE, dmPelsWidth, "UInt")
      fields |= DM.PELSWIDTH
   }
   If (sH <> "") {
      NumPut(sH, DEVMODE, dmPelsHeight, "UInt")
      fields |= DM.PELSHEIGHT
   }
   If (rR <> "") {
      NumPut(rR, DEVMODE, dmDisplayFrequency, "UInt")
      fields |= DM.DISPLAYFREQUENCY
   }
   If (fields > 0) {
      NumPut(fields, DEVMODE, dmFields, "UInt")
      dmAddr := &DEVMODE
   }
   
   If (Perm=1) ;Resolution change will continue after exiting program.
      Return DllCall("User32.dll\ChangeDisplaySettings", "Ptr", dmAddr, "UInt", 0, "Int")
   else ;Resolution change will revert to original after exiting program. 
      Return DllCall("User32.dll\ChangeDisplaySettings", "Ptr", dmAddr, "UInt", 4, "Int")
}

ClipboardGetDropEffect() {
/*
    Retrieves the preferred method of data transfer (preferred drop effect set by source).
    Return value:
        If the function succeeds, the return value is one of the following.
        1  DROPEFFECT_COPY      The source should copy the data. The original data is untouched.
        2  DROPEFFECT_MOVE      The source should remove the data.
        5                       This value also indicates copy (DROPEFFECT_COPY).
        ---------------------------------------------------
        Any other value is considered an error.
        -1        No data transfer operation found.
        -2        The clipboard could not be opened.
    Windows Clipboard Formats:
        https://www.codeproject.com/Reference/1091137/Windows-Clipboard-Formats
*/
; to-do ; fix this

   If !IsClipboardFormatAvailable(15)
      Return -1

   If !DllCall("OpenClipboard", "UPtr", A_ScriptHwnd)
      Return -2

   h := DllCall("User32.dll\GetClipboardData", "UInt", 15, "UPtr") ; CF_HDROP = 15
   z := DllCall("Kernel32.dll\GlobalLock", "Ptr", h, "Ptr")
   If z
      r := NumGet(z, 0, "Int")
   g := DllCall("Kernel32.dll\GlobalUnlock", "Ptr", h, "Ptr")
   DllCall("CloseClipboard")
   Return r
}

IsClipboardFormatAvailable(typeu) {
/*
    Values for typeu     Description
    CF_TEXT = 1          Text format. Each line ends with a carriage return/linefeed (CR-LF) combination. A null character signals the end of the data. Use this format for ANSI text.
    CF_BITMAP = 2        A handle to a bitmap (HBITMAP).
    CF_METAFILEPICT = 3  Handle to a metafile picture format as defined by the METAFILEPICT structure. When passing a CF_METAFILEPICT handle by means of DDE, the application responsible for deleting hMem should also free the metafile referred to by the CF_METAFILEPICT handle.
    CF_SYLK =  4         Microsoft Symbolic Link (SYLK) format.
    CF_DIF = 5           Software Arts' Data Interchange Format.
    CF_TIFF = 6          Tagged-image file format.
    CF_OEMTEXT = 7       Text format containing characters in the OEM character set. Each line ends with a carriage return/linefeed (CR-LF) combination. A null character signals the end of the data.
    CF_DIB = 8           A memory object containing a BITMAPINFO structure followed by the bitmap bits.
    CF_PENDATA = 10      Data for the pen extensions to the Microsoft Windows for Pen Computing.
    CF_RIFF = 11         Represents audio data more complex than can be represented in a CF_WAVE standard wave format.
    CF_WAVE = 12         Represents audio data in one of the standard wave formats, such as 11 kHz or 22 kHz PCM.
    CF_UNICODETEXT = 13  Unicode text format. Each line ends with a carriage return/linefeed (CR-LF) combination. A null character signals the end of the data.
    CF_ENHMETAFILE = 14  A handle to an enhanced metafile (HENHMETAFILE).
    CF_HDROP = 15        A handle to type HDROP that identifies a list of files. An application can retrieve information about the files by passing the handle to the DragQueryFile function.
    CF_DIBV5 = 17        A memory object containing a BITMAPV5HEADER structure followed by the bitmap color space information and the bitmap bits.
    CF_DSPBITMAP = 0x0082
        Bitmap display format associated with a private format. The hMem parameter must be a handle to data that can be displayed in bitmap format in lieu of the privately formatted data.
    CF_DSPENHMETAFILE = 0x008E
        Enhanced metafile display format associated with a private format. The hMem parameter must be a handle to data that can be displayed in enhanced metafile format in lieu of the privately formatted data.
    CF_DSPMETAFILEPICT = 0x0083
        Metafile-picture display format associated with a private format. The hMem parameter must be a handle to data that can be displayed in metafile-picture format in lieu of the privately formatted data.
    CF_DSPTEXT = 0x0081
        Text display format associated with a private format. The hMem parameter must be a handle to data that can be displayed in text format in lieu of the privately formatted data.
    CF_GDIOBJFIRST = 0x0300
        Start of a range of integer values for application-defined GDI object clipboard formats. The end of the range is CF_GDIOBJLAST.
    Handles associated with clipboard formats in this range are not automatically deleted using the GlobalFree function when the clipboard is emptied. Also, when using values in this range, the hMem parameter is not a handle to a GDI object, but is a handle allocated by the GlobalAlloc function with the GMEM_MOVEABLE flag.
    CF_GDIOBJLAST = 0x03FF
        See CF_GDIOBJFIRST.
    CF_LOCALE =  16
        The data is a handle (HGLOBAL) to the locale identifier (LCID) associated with text in the clipboard. When you close the clipboard, if it contains CF_TEXT data but no CF_LOCALE data, the system automatically sets the CF_LOCALE format to the current input language. You can use the CF_LOCALE format to associate a different locale with the clipboard text.
        An application that pastes text from the clipboard can retrieve this format to determine which character set was used to generate the text.
        Note that the clipboard does not support plain text in multiple character sets. To achieve this, use a formatted text data type such as RTF instead.
        The system uses the code page associated with CF_LOCALE to implicitly convert from CF_TEXT to CF_UNICODETEXT. Therefore, the correct code page table is used for the conversion.
    CF_OWNERDISPLAY =  0x0080
        Owner-display format. The clipboard owner must display and update the clipboard viewer window, and receive the WM_ASKCBFORMATNAME, WM_HSCROLLCLIPBOARD, WM_PAINTCLIPBOARD, WM_SIZECLIPBOARD, and WM_VSCROLLCLIPBOARD messages. The hMem parameter must be NULL.
    CF_PALETTE = 9
        Handle to a color palette. Whenever an application places data in the clipboard that depends on or assumes a color palette, it should place the palette on the clipboard as well.
        If the clipboard contains data in the CF_PALETTE (logical color palette) format, the application should use the SelectPalette and RealizePalette functions to realize (compare) any other data in the clipboard against that logical palette.
        When displaying clipboard data, the clipboard always uses as its current palette any object on the clipboard that is in the CF_PALETTE format.
    CF_PRIVATEFIRST = 0x0200
        Start of a range of integer values for private clipboard formats. The range ends with CF_PRIVATELAST. Handles associated with private clipboard formats are not freed automatically; the clipboard owner must free such handles, typically in response to the WM_DESTROYCLIPBOARD message.
    CF_PRIVATELAST = 0x02FF
        See CF_PRIVATEFIRST.
*/ 

   Return DllCall("IsClipboardFormatAvailable", "uint", typeu)
}

ShowTrackPopupMenu(HMENU, X, Y, HWND, Flags:=0) {
   ; http://msdn.microsoft.com/en-us/library/ms648002(v=vs.85).aspx
   ; X-position: TPM_CENTERALIGN := 0x0004, TPM_LEFTALIGN := 0x0000, TPM_RIGHTALIGN := 0x0008
   ; Y-position: TPM_BOTTOMALIGN := 0x0020, TPM_TOPALIGN := 0x0000, TPM_VCENTERALIGN := 0x0010
  
   ; Retrieve the number of items in a menu.
   item_count := DllCall("GetMenuItemCount", "ptr", MenuGetHandle("MyMenu"))

   ; Retrieve the ID of the last item.
   last_id := DllCall("GetMenuItemID", "ptr", MenuGetHandle("MyMenu"), "int", item_count-1)
   Return DllCall("User32.dll\TrackPopupMenu", "UPtr", HMENU, "UInt", Flags, "Int", X, "Int", Y, "Int", 0
                                             , "UPtr", HWND, "Ptr", 0, "UInt")
} 

GetWinHwndAtPoint(nX, nY) {
    a := DllCall("WindowFromPhysicalPoint", "Uint64", nX|(nY << 32), "Ptr")
    a := Format("{1:#x}", a)
    WinGetClass, h, ahk_id %a%
    Return [a, h]
}

TabCtrl_GetCurSel(HWND) {
   ; by just me 
   ; source: https://www.autohotkey.com/board/topic/79783-how-to-get-the-current-tab-name/
   ; Returns the 1-based index of the currently selected tab
   Static TCM_GETCURSEL := 0x130B
   SendMessage, TCM_GETCURSEL, 0, 0, , ahk_id %HWND%
   Return (ErrorLevel + 1)
}

TabCtrl_GetItemText(HWND, Index:=0) {
   ; by just me ; modified and fixed by Marius Șucan
   ; source: https://www.autohotkey.com/board/topic/79783-how-to-get-the-current-tab-name/
   Static TCM_GETITEM  := A_IsUnicode ? 0x133C : 0x1305 ; TCM_GETITEMW : TCM_GETITEMA
   Static TCIF_TEXT := 0x0001
   Static TCTXTP := (3 * 4) + (A_PtrSize - 4)
   Static TCTXLP := TCTXTP + A_PtrSize
   ErrorLevel := 0
   If (Index = 0)
      Index := TabCtrl_GetCurSel(HWND)
   If (Index = 0)
      Return 0

   VarSetCapacity(TCTEXT, 256 * 4, 0)
   ; typedef struct {
   ;   UINT   mask;           4
   ;   DWORD  dwState;        4
   ;   DWORD  dwStateMask;    4 + 4 bytes padding on 64-bit systems
   ;   LPTSTR pszText;        4 / 8 (32-bit / 64-bit)
   ;   int    cchTextMax;     4
   ;   int    iImage;         4
   ;   LPARAM lParam;         4 / 8
   ; } TCITEM, *LPTCITEM;

   VarSetCapacity(TCITEM, (5 * 4) + (2 * A_PtrSize) + (A_PtrSize - 4), 0)
   NumPut(TCIF_TEXT, TCITEM, 0, "UInt")
   NumPut(&TCTEXT, TCITEM, TCTXTP, "Ptr")
   NumPut(256, TCITEM, TCTXLP, "Int")

   SendMessage, % TCM_GETITEM, % Index - 1, &TCITEM, , ahk_id %HWND%
   If !ErrorLevel
      Return 

   name := StrGet(NumGet(TCITEM, TCTXTP, "UPtr"))
   TCITEM :=  ""
   TCTEXT := ""
   ; ToolTip, % name , , , 2
   Return name
}

BalloonTip(sText, sTitle:="BalloonTip", Options:="", darkMode:=0) {
; Example: BalloonTip("how are you ?", "Mr.World says hello", "I=2 C=001100 T=2")
; Source: https://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/
; updated by Marius Șucan -- mardi 8 mars 2022

  ;    BalloonTip  -  AHK, AHK_L compatible
  ; *****************************************************************************************************************************
  ;  Options: Space separated string of options bellow like (X=10 Y=10 I=1 T=2000 C=FFFFFF). ( Default Options in [] ).
  ;  X= x position [mouse x]
  ;  Y= y position [mouse y]
  ;  T= Timeout in seconds [0]
  ;  I= Icon 0:None, [1], 2:Warning, 3:Error, >3:assumed to be an hIcon.
  ;  C= RGB color for background (like 0xFF00FF or FF00FF), text uses compliment color, [1]
  ;  Q= Theme [1], Use 0 to disable Theme for colors to work in Vista, Win7.
  ;  NOTE: To Close it before Timeout, use command (WinClose,  ahk_id %<Returned hWnd>%)
  ; ******************************************************************************************************************************
  STATIC hWnd, X, Y, T, W, I, C, Q  ; Options STATIC to force local variables
       , prevHwnd, lastTimer, lastInvoked

  If (prevHwnd && lastTimer && (A_TickCount - lastInvoked < lastTimer) || sText="-" && options="close")
  {
     If prevHwnd
        WinClose, ahk_id %prevHwnd%
     prevHwnd :=""
     If (options="close")
        Return
  }

  X:=Y:="", T:=W:=0, I:=C:=Q:=1, Ptr:=(A_PtrSize ? "Ptr" : "UInt"), sTitle:=((StrLen(sTitle)<99) ? sTitle : (SubStr(sTitle,1,95) . " ..."))
  Loop, Parse, Options, %A_Space%=, %A_Space%%A_Tab%`r`n
      A_Index & 1  ? (Var:=A_LoopField) : (%Var%:=A_LoopField)

  DllCall("GetCursorPos", "int64P", pt), X:=(!X ? pt << 32 >> 32 : X), Y:=(!Y ? pt >> 32 : Y)
  a:=((C=1) ? ((hDC:=DllCall("GetDC","Uint",0)) (C:=DllCall("GetPixel","Uint",hDC,"int",X,"int",Y)) (DllCall("ReleaseDC","Uint",0,"Uint",hDC))) : ((C:=(StrLen(C)<8 ? "0x" : "") . C) (C:=((C&255)<<16)+(((C>>8)&255)<<8)+(C>>16)))) ; rgb -> bgr
  VarSetCapacity(ti,(A_PtrSize ? 28+A_PtrSize*3 : 40),0), ti:=Chr((A_PtrSize ? 28+A_PtrSize*3 : 40)), NumPut(0x20,ti,4,"UInt"), NumPut(&sText,&ti,(A_PtrSize ? 24+A_PtrSize*3 : 36))
  hWnd:=DllCall("CreateWindowEx",Ptr,0x8,"str","tooltips_class32","str","",Ptr,0xC3,"int",0,"int",0,"int",0,"int",0,Ptr,0,Ptr,0,Ptr,0,Ptr,0,Ptr)
  If (darkMode=1)
     DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "str", "DarkMode_Explorer", "ptr", 0)

  a:=(Q ? DllCall("SendMessage","UPtr",hWnd,Ptr,0x200b,Ptr,0,Ptr,"") : DllCall("uxtheme\SetWindowTheme","UPtr",hWnd,Ptr,0,"UintP",0)) ; TTM_SETWINDOWTHEME

  DllCall("SendMessage", "UPtr", hWnd, "Uint", 1028, Ptr, 0, Ptr, &ti, Ptr)        ; TTM_ADDTOOL
  DllCall("SendMessage", "UPtr", hWnd, "Uint", 1041, Ptr, 1, Ptr, &ti, Ptr)        ; TTM_TRACKACTIVATE
  DllCall("SendMessage", "UPtr", hWnd, "Uint", 1042, Ptr, 0, Ptr, (X & 0xFFFF)|(Y & 0xFFFF)<<16,Ptr)  ; TTM_TRACKPOSITION
  DllCall("SendMessage", "UPtr", hWnd, "Uint", 1043, Ptr, C, Ptr,   0, Ptr)        ; TTM_SETTIPBKCOLOR
  DllCall("SendMessage", "UPtr", hWnd, "Uint", 1044, Ptr, ~C & 0xFFFFFF,  Ptr, 0,Ptr)    ; TTM_SETTIPTEXTCOLOR
  DllCall("SendMessage", "UPtr", hWnd, "Uint",(A_IsUnicode ? 1057 : 1056),Ptr, I,Ptr, &sTitle, Ptr)  ; TTM_SETTITLE 0:None, 1:Info, 2:Warning, 3:Error, >3:assumed to be an hIcon.
  DllCall("SendMessage", "UPtr", hWnd, "Uint", 1048, Ptr, 0, Ptr, A_ScreenWidth)      ; TTM_SETMAXTIPWIDTH
  DllCall("SendMessage", "UPtr", hWnd, "UInt",(A_IsUnicode ? 0x439 : 0x40c), Ptr, 0, Ptr, &ti, Ptr)  ; TTM_UPDATETIPTEXT (OLD_MSG=1036)
  ; IfGreater, I, 0, SoundPlay, % "*" . (I=2 ? 48 : I=3 ? 16 : 64)

  If (T>0)
  {
     lastTimer := T*1000
     lastInvoked := A_TickCount
     SetTimer, BalloonTip_Kill, % -T*1000
  }
  prevHwnd := hwnd
  Return hWnd        ; Close it before TimeOut.
}

BalloonTip_Kill() {
    BalloonTip("-", "-", "close")
}

EM_ISIME(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x4F3, "Int", 0, "Int", 0)
  Return result
}

EM_CANREDO(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x0455, "Int", 0, "Int", 0)
  Return result
}

EM_CANUNDO(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x00C6, "Int", 0, "Int", 0)
  Return result
}

EM_GETLINECOUNT(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x00BA, "Int", 0, "Int", 0)
  Return result
}

EM_CHARFROMPOS(hEdit, X, Y, linePos:=0) {
; from https://github.com/dufferzafar/Autohotkey-Scripts/blob/master/lib/RichEdit.ahk
; modified by Marius Șucan

  WinGetClass, classu, ahk_id %hEdit%
  If InStr(classu, "RICHEDIT50W")
  {
     VarSetCapacity(POINTL, 8)
     lParam := &POINTL
     NumPut(X, POINTL)
     NumPut(Y, POINTL)
  } Else lParam := (Y<<16)|X

  r := DllCall("SendMessage", "UInt", hEdit, "UInt", 0xD7, "Int", 0, "UInt", lParam)
  If (linePos=1)
     result := (r >> 16) & 0xffff      ; return the HIWORD
  Else
     result := r & 0xffff      ; return the LOWORD
  Return result
}

EM_POSFROMCHAR(hCtrl, s1:=0, h:=0) {
   x := result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0xD6, "Int", s1, "UInt", 0)  ; EM_POSFROMCHAR
   If (h=1)
      y := result := (result >> 16) & 0xffff   ; HIWORD
   Return result
}

WM_GETTEXTLENGTH(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0xE, "Ptr", 0, "Ptr", 0)  ; WM_GETTEXTLENGTH
  Return result
}

EM_GETSEL(hCtrl, opt:="b") {
; options: [s]tart, [e]nd, [b]oth
   r := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0xB0, "IntP", s1, "IntP", s2)     ; EM_GETSEL
   Return (opt="s" ? s1 : opt="e" ? s2 : s1|(s2<<32))
}

EM_SETSEL(hCtrl, s1:=0, s2:="") {
   s2 := (s2="") ? s1 : s2
   r:= DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0xB1, "Int", s1, "Int", s2)      ; EM_SETSEL
   Return r
}

EM_SETCUEBANNER(handle, string, option := true) {
; ===============================================================================================================================
; Message ..................:  EM_SETCUEBANNER
; Minimum supported client .:  Windows Vista
; Minimum supported server .:  Windows Server 2003
; Links ....................:  https://docs.microsoft.com/en-us/windows/win32/controls/em-setcuebanner
; Description ..............:  Sets the textual cue, or tip, that is displayed by the edit control to prompt the user for information.
; Options ..................:  True  -> if the cue banner should show even when the edit control has focus
;                              False -> if the cue banner disappears when the user clicks in the control
; ===============================================================================================================================
   static ECM_FIRST       := 0x1500 
        , EM_SETCUEBANNER := ECM_FIRST + 1
   if (DllCall("user32\SendMessage", "ptr", handle, "uint", EM_SETCUEBANNER, "int", option, "str", string, "int"))
      return 1
   return 0
}

EM_UNDO(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0xC7, "Int", 0, "Int", 0)
  Return result
}

EM_REDO(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x454, "Int", 0, "Int", 0)
  Return result
}

WM_COPY(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x301, "Int", 0, "Int", 0)
  Return result
}

WM_CUT(hCtrl) {
  result := DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x300, "Int", 0, "Int", 0)
  Return result
}

ClipboardSetFiles(PathsFilesArray, Method:="copy", foldersMode:=0) {
; function from https://autohotkey.com/board/topic/23162-how-to-copy-a-file-to-the-clipboard/page-4
; by maraskan_user and Lexikos
; modified by Marius Șucan

   FileCount := PathLength := 0
   ; Count files and total string length from given array
   For i, File in PathsFilesArray
   {
      FileCount++
      PathLength += StrLen(File)
   }

   If (!FileCount || !PathLength)
      Return

   pid := DllCall("GetCurrentProcessId","uint")
   hwnd := WinExist("ahk_pid " . pid)
   ; 0x42 = GMEM_MOVEABLE(0x2) | GMEM_ZEROINIT(0x40)
   hPath := DllCall("GlobalAlloc","uint",0x42,"uint",20 + (PathLength + FileCount + 1) * 2, "UPtr")
   If !hPath
      Return

   pPath := DllCall("GlobalLock","UPtr", hPath, "UPtr")
   NumPut(20, pPath+0), pPath += 16 ; DROPFILES.pFiles = offset of file list
   NumPut(1, pPath+0), pPath += 4 ; fWide = 0 -->ANSI,fWide = 1 -->Unicode

   Offset := 0
   ; Rows are delimited by linefeeds (`r`n).
   for i, File in PathsFilesArray
       offset += StrPut(File, pPath + offset, StrLen(File)+1, "UTF-16") * 2

   DllCall("GlobalUnlock","UPtr",hPath)
   If !DllCall("OpenClipboard","UPtr", hwnd)
      Return

   DllCall("EmptyClipboard")
   err := DllCall("SetClipboardData","uint",0xF,"UPtr",hPath) ; 0xF = CF_HDROP

   ; Write Preferred DropEffect structure to clipboard to switch between copy/cut operations
   ; 0x42 = GMEM_MOVEABLE(0x2) | GMEM_ZEROINIT(0x40)
   mem := DllCall("GlobalAlloc","uint",0x42,"uint",4,"UPtr")
   If mem
   {
      str := DllCall("GlobalLock","UPtr",mem, "uptr")
   } Else
   {
      DllCall("CloseClipboard")
      Return
   }

   if (Method="copy")
   {
      DllCall("RtlFillMemory","UPtr",str,"UPtr",1,"Int",0x05)
   } else if (Method="cut")
   {
      DllCall("RtlFillMemory","UPtr",str,"UPtr",1,"Int",0x02)
   } else
   {
      DllCall("CloseClipboard")
      Return
   }

   DllCall("GlobalUnlock","UPtr",mem)
   If (foldersMode=1)
   {
      cfFormat := DllCall("RegisterClipboardFormat","Str","DropEffectFolderList")
      err := DllCall("SetClipboardData","uint",cfFormat,"UPtr",mem)
   }   

   cfFormat := DllCall("RegisterClipboardFormat","Str","Preferred DropEffect")
   err := DllCall("SetClipboardData","uint",cfFormat,"UPtr",mem)
   DllCall("CloseClipboard")
   return err
}

GetComboBoxInfo(hwnd) {
; based on https://www.autohotkey.com/boards/viewtopic.php?t=69158
; updated by Marius Șucan

   ; https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getcomboboxinfo
   CBBISize := 40 + (3 * A_PtrSize)
   VarSetCapacity(CBBInfo, CBBISize, 0)
   NumPut(CBBISize, CBBInfo, 0, "UInt")
   r := DllCall("User32.dll\GetComboBoxInfo", "UPtr", hwnd, "UPtr", &CBBInfo)
   HCBBEDIT := NumGet(CBBInfo, 40 + A_PtrSize, "UPtr")
   HCBBLIST := NumGet(CBBInfo, 40 + (2 * A_PtrSize), "UPtr")
   CBBInfo := ""
   Return [HCBBEDIT, HCBBLIST, r]
}

GetWindowFromPos(X, Y, DetectHidden := 0) {
   ; by just me https://www.autohotkey.com/boards/viewtopic.php?p=80118
   ; CWP_ALL = 0x0000, CWP_SKIPINVISIBLE = 0x0001
   Return DllCall("ChildWindowFromPointEx", "UPtr", DllCall("GetDesktopWindow", "UPtr")
                                          , "Int64", (X & 0xFFFFFFFF) | ((Y & 0xFFFFFFFF) << 32)
                                          , "UInt", !DetectHidden, "UPtr")
}

AddTooltip2Ctrl(p1, p2:="", p3="", darkMode:=0, largeFont:=0) {
; Description: AddTooltip v2.0
;   Add/Update tooltips to GUI controls.
;
; Parameters:
;   p1 - Handle to a GUI control.  Alternatively, set to "Activate" to enable
;       the tooltip control, "AutoPopDelay" to set the autopop delay time,
;       "Deactivate" to disable the tooltip control, or "Title" to set the
;       tooltip title.
;
;   p2 - If p1 contains the handle to a GUI control, this parameter should
;       contain the tooltip text.  Ex: "My tooltip".  Set to null to delete the
;       tooltip attached to the control.  If p1="AutoPopDelay", set to the
;       desired autopop delay time, in seconds.  Ex: 10.  Note: The maximum
;       autopop delay time is ~32 seconds.  If p1="Title", set to the title of
;       the tooltip.  Ex: "Bob's Tooltips".  Set to null to remove the tooltip
;       title.  See the *Title & Icon* section for more information.
;
;   p3 - Tooltip icon.  See the *Title & Icon* section for more information.
;
; RETURNS: The handle to the tooltip control.
; REQUIREMENTS: AutoHotkey v1.1+ (all versions).
;
; TITLE AND ICON:
;   To set the tooltip title, set the p1 parameter to "Title" and the p2
;   parameter to the desired tooltip title.  Ex: AddTooltip("Title","Bob's
;   Tooltips"). To remove the tooltip title, set the p2 parameter to null.  Ex:
;   AddTooltip("Title","").
;
;   The p3 parameter determines the icon to be displayed along with the title,
;   if any.  If not specified or if set to 0, no icon is shown.  To show a
;   standard icon, specify one of the standard icon identifiers.  See the
;   function's static variables for a list of possible values.  Ex:
;   AddTooltip("Title","My Title",4).  To show a custom icon, specify a handle
;   to an image (bitmap, cursor, or icon).  When a custom icon is specified, a
;   copy of the icon is created by the tooltip window so if needed, the original
;   icon can be destroyed any time after the title and icon are set.
;
;   Setting a tooltip title may not produce a desirable result in many cases.
;   The title (and icon if specified) will be shown on every tooltip that is
;   added by this function.
;
; REMARKS:
;   The tooltip control is enabled by default.  There is no need to "Activate"
;   the tooltip control unless it has been previously "Deactivated".
;
;   This function returns the handle to the tooltip control so that, if needed,
;   additional actions can be performed on the Tooltip control outside of this
;   function.  Once created, this function reuses the same tooltip control.
;   If the tooltip control is destroyed outside of this function, subsequent
;   calls to this function will fail.
;
; CREDIT AND HISTORY:
;   Original author: Superfraggle
;   * Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/>
;
;   Updated to support Unicode: art
;   * Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/page-2#entry431059>
;
;   Additional: jballi.
;   Bug fixes.  Added support for x64.  Removed Modify parameter.  Added
;   additional functionality, constants, and documentation.

    Static hTT
          ;-- Misc. constants
          ,CW_USEDEFAULT:=0x80000000
          ,HWND_DESKTOP :=0

          ;-- Tooltip delay time constants
          ,TTDT_AUTOPOP:=2
                ;-- Set the amount of time a tooltip window remains visible if
                ;   the pointer is stationary within a tool's bounding
                ;   rectangle.

          ;-- Tooltip styles
          ,TTS_ALWAYSTIP:=0x1
                ;-- Indicates that the tooltip control appears when the cursor
                ;   is on a tool, even if the tooltip control's owner window is
                ;   inactive.  Without this style, the tooltip appears only when
                ;   the tool's owner window is active.

          ,TTS_NOPREFIX:=0x2
                ;-- Prevents the system from stripping ampersand characters from
                ;   a string or terminating a string at a tab character.
                ;   Without this style, the system automatically strips
                ;   ampersand characters and terminates a string at the first
                ;   tab character.  This allows an application to use the same
                ;   string as both a menu item and as text in a tooltip control.

          ;-- TOOLINFO uFlags
          ,TTF_IDISHWND:=0x1
                ;-- Indicates that the uId member is the window handle to the
                ;   tool.  If this flag is not set, uId is the identifier of the
                ;   tool.

          ,TTF_SUBCLASS:=0x10
                ;-- Indicates that the tooltip control should subclass the
                ;   window for the tool in order to intercept messages, such
                ;   as WM_MOUSEMOVE.  If this flag is not used, use the
                ;   TTM_RELAYEVENT message to forward messages to the tooltip
                ;   control.  For a list of messages that a tooltip control
                ;   processes, see TTM_RELAYEVENT.

          ;-- Tooltip icons
          ,TTI_NONE         :=0
          ,TTI_INFO         :=1
          ,TTI_WARNING      :=2
          ,TTI_ERROR        :=3
          ,TTI_INFO_LARGE   :=4
          ,TTI_WARNING_LARGE:=5
          ,TTI_ERROR_LARGE  :=6

          ;-- Extended styles
          ,WS_EX_TOPMOST:=0x8

          ;-- Messages
          ,TTM_ACTIVATE      :=0x401                    ;-- WM_USER + 1
          ,TTM_ADDTOOLA      :=0x404                    ;-- WM_USER + 4
          ,TTM_ADDTOOLW      :=0x432                    ;-- WM_USER + 50
          ,TTM_DELTOOLA      :=0x405                    ;-- WM_USER + 5
          ,TTM_DELTOOLW      :=0x433                    ;-- WM_USER + 51
          ,TTM_GETTOOLINFOA  :=0x408                    ;-- WM_USER + 8
          ,TTM_GETTOOLINFOW  :=0x435                    ;-- WM_USER + 53
          ,TTM_SETDELAYTIME  :=0x403                    ;-- WM_USER + 3
          ,TTM_SETMAXTIPWIDTH:=0x418                    ;-- WM_USER + 24
          ,TTM_SETTITLEA     :=0x420                    ;-- WM_USER + 32
          ,TTM_SETTITLEW     :=0x421                    ;-- WM_USER + 33
          ,TTM_UPDATETIPTEXTA:=0x40C                    ;-- WM_USER + 12
          ,TTM_UPDATETIPTEXTW:=0x439                    ;-- WM_USER + 57

    If (p1="reset")
    {
       If hTT
          DllCall("DestroyWindow", "Ptr", hTT)
       hTT := ""
       Return
    }

    if (DisableTooltips=1)
       return 

    ;-- Save/Set DetectHiddenWindows
    l_DetectHiddenWindows:=A_DetectHiddenWindows
    DetectHiddenWindows On

    ;-- Tooltip control exists?
    if !hTT
    {
        ;-- Create Tooltip window
        hTT:=DllCall("CreateWindowEx"
            ,"UInt",WS_EX_TOPMOST                       ;-- dwExStyle
            ,"Str","TOOLTIPS_CLASS32"                   ;-- lpClassName
            ,"Ptr",0                                    ;-- lpWindowName
            ,"UInt",TTS_ALWAYSTIP|TTS_NOPREFIX          ;-- dwStyle
            ,"UInt",CW_USEDEFAULT                       ;-- x
            ,"UInt",CW_USEDEFAULT                       ;-- y
            ,"UInt",CW_USEDEFAULT                       ;-- nWidth
            ,"UInt",CW_USEDEFAULT                       ;-- nHeight
            ,"Ptr",HWND_DESKTOP                         ;-- hWndParent
            ,"Ptr",0                                    ;-- hMenu
            ,"Ptr",0                                    ;-- hInstance
            ,"Ptr",0                                    ;-- lpParam
            ,"Ptr")                                     ;-- Return type

        ;-- Disable visual style
        ;   Note: Uncomment the following to disable the visual style, i.e.
        ;   remove the window theme, from the tooltip control.  Since this
        ;   function only uses one tooltip control, all tooltips created by this
        ;   function will be affected.
        ;   DllCall("uxtheme\SetWindowTheme","Ptr",hTT,"Ptr",0,"UIntP",0)

        If (darkMode=1)
           DllCall("uxtheme\SetWindowTheme", "ptr", HTT, "str", "DarkMode_Explorer", "ptr", 0)
        ;-- Set the maximum width for the tooltip window
        ;   Note: This message makes multi-line tooltips possible
        SendMessage, TTM_SETMAXTIPWIDTH, 0, A_ScreenWidth,, ahk_id %hTT%
        If (largeFont=1)
        {
           hFont := Gdi_CreateFontByName("MS Shell Dlg 2", 20, 400, 0, 0, 0, 4)
           SendMessage, 0x30, hFont, 1,,ahk_id %hTT% ; WM_SETFONT
        }
    }

    ;-- Other commands
    if p1 is not Integer
    {
        if (p1="Activate")
            SendMessage, TTM_ACTIVATE, True, 0,, ahk_id %hTT%

        if (p1="Deactivate")
            SendMessage, TTM_ACTIVATE, False, 0,, ahk_id %hTT%

        if (InStr(p1,"AutoPop")=1)  ;-- Starts with "AutoPop"
            SendMessage, TTM_SETDELAYTIME, TTDT_AUTOPOP, p2*1000,, ahk_id %hTT%

        if (p1="Title")
        {
            ;-- If needed, truncate the title
            if (StrLen(p2)>99)
                p2 := SubStr(p2,1,99)

            ;-- Icon
            if p3 is not Integer
                p3 := TTI_NONE

            ;-- Set title
            SendMessage A_IsUnicode ? TTM_SETTITLEW : TTM_SETTITLEA, p3, &p2,, ahk_id %hTT%
        }

        ;-- Restore DetectHiddenWindows
        DetectHiddenWindows %l_DetectHiddenWindows%
    
        ;-- Return the handle to the tooltip control
        Return hTT
    }

    ;-- Create/Populate the TOOLINFO structure
    uFlags := TTF_IDISHWND | TTF_SUBCLASS
    cbSize := VarSetCapacity(TOOLINFO,(A_PtrSize=8) ? 64:44,0)
    NumPut(cbSize,      TOOLINFO,0,"UInt")              ;-- cbSize
    NumPut(uFlags,      TOOLINFO,4,"UInt")              ;-- uFlags
    NumPut(HWND_DESKTOP,TOOLINFO,8,"Ptr")               ;-- hwnd
    NumPut(p1,          TOOLINFO,(A_PtrSize=8) ? 16:12,"Ptr")
        ;-- uId

    ;-- Check to see if tool has already been registered for the control
    SendMessage, A_IsUnicode ? TTM_GETTOOLINFOW : TTM_GETTOOLINFOA
               , 0, &TOOLINFO,, ahk_id %hTT%

    l_RegisteredTool := ErrorLevel

    ;-- Update the TOOLTIP structure
    NumPut(&p2, TOOLINFO, (A_PtrSize=8) ? 48 : 36,"Ptr")
        ;-- lpszText

    ;-- Add, Update, or Delete tool
    if l_RegisteredTool
    {
        if StrLen(p2)
            SendMessage, A_IsUnicode ? TTM_UPDATETIPTEXTW : TTM_UPDATETIPTEXTA, 0, &TOOLINFO,, ahk_id %hTT%
        else
            SendMessage, A_IsUnicode ? TTM_DELTOOLW : TTM_DELTOOLA, 0, &TOOLINFO,, ahk_id %hTT%
    } else if StrLen(p2)
    {
        SendMessage, A_IsUnicode ? TTM_ADDTOOLW : TTM_ADDTOOLA, 0, &TOOLINFO,, ahk_id %hTT%
    }

    ;-- Restore DetectHiddenWindows
    DetectHiddenWindows %l_DetectHiddenWindows%
    ;-- Return the handle to the tooltip control
    Return hTT
}

WinEnumChild(hwnd:=0, lParam:=0) {
/* Function: WinEnumChild
 *     Wrapper for Enum(Child)Windows [http://goo.gl/5eCy9 | http://goo.gl/FMXit]
 * Source: https://github.com/cocobelgica/AutoHotkey-Util/blob/master/WinEnum.ahk
 * License: WTFPL [http://wtfpl.net/]
 * Syntax: windows := WinEnum( [ hwnd ] )
 * Parameter(s) / Return Value:
 *     windows    [retval]  - an array of window handles
 *     hwnd       [in, opt] - parent window. If specified, EnumChildWindows is
 *                            called. Accepts a window handle or any string that
 *                            match the WinTitle[http://goo.gl/NdhybZ] parameter.
 *     lParam     [internal, used by callback]
 *
 * Example:
 *     win := WinEnum() ; calls EnumWindows
 *     children := WinEnum("A") ; enumerate child windows of the active window
*/

  static pWinEnum := "X"
  if (A_EventInfo!=pWinEnum)
  {
     if (pWinEnum=="X")
        pWinEnum := RegisterCallback(A_ThisFunc, "F", 2)

     if hwnd
     {
       ;// not a window handle, could be a WinTitle parameter
       if !DllCall("IsWindow", "Ptr", hwnd)
       {
          prev_DHW := A_DetectHiddenWindows
          prev_TMM := A_TitleMatchMode
          DetectHiddenWindows On
          SetTitleMatchMode 2
          hwnd := WinExist(hwnd)
          DetectHiddenWindows %prev_DHW%
          SetTitleMatchMode %prev_TMM%
       }
    }
    out := []
    if hwnd
       DllCall("EnumChildWindows", "Ptr", hwnd, "Ptr", pWinEnum, "Ptr", &out)
    else
       DllCall("EnumWindows", "Ptr", pWinEnum, "Ptr", &out)
    return out
  }

  ;// Callback - EnumWindowsProc / EnumChildProc
  static ObjPush := Func(A_AhkVersion < "2" ? "ObjInsert" : "ObjPush")
  %ObjPush%(Object(lParam + 0), hwnd)
  return true
}

Win_ShowSysMenu(Hwnd, x, y) {
; Source: https://github.com/majkinetor/mm-autohotkey/blob/master/Appbar/Taskbar/Win.ahk
; modified by Marius Șucan

  Static WM_SYSCOMMAND := 0x112, TPM_RETURNCMD := 0x100
  h := WinExist("ahk_id " hwnd)
  hSysMenu := DllCall("GetSystemMenu", "Uint", Hwnd, "int", False) 
  r := DllCall("TrackPopupMenu", "uint", hSysMenu, "uint", TPM_RETURNCMD, "int", X, "int", Y, "int", 0, "uint", h, "uint", 0)
  If (r=0)
     Return

  SendMessage, WM_SYSCOMMAND, r,,,ahk_id %Hwnd%
  Return 1
}

GetClientPos(hwnd, ByRef left, ByRef top, ByRef w, ByRef h) {
  ; source http://forum.script-coding.com/viewtopic.php?pid=81833#p81833
  Static r := VarSetCapacity(pwi, 60, 0)
  s := DllCall("GetWindowInfo", "Ptr", hwnd, "Ptr", &pwi)
  left := NumGet(pwi, 20, "Int") - NumGet(pwi, 4, "Int")
  top := NumGet(pwi, 24, "Int") - NumGet(pwi, 8, "Int")
  w := NumGet(pwi, 28, "Int") - NumGet(pwi, 20, "Int")
  h := NumGet(pwi, 32, "Int") - NumGet(pwi, 24, "Int")
  Return s
}

GetWindowBounds(hWnd) {
   ; function by GeekDude: https://gist.github.com/G33kDude/5b7ba418e685e52c3e6507e5c6972959
   ; W10 compatible function to find a window's visible boundaries
   ; modified by Marius Șucan to return an array
   size := VarSetCapacity(rect, 16, 0)
   er := DllCall("dwmapi\DwmGetWindowAttribute"
      , "UPtr", hWnd  ; HWND  hwnd
      , "UInt", 9     ; DWORD dwAttribute (DWMWA_EXTENDED_FRAME_BOUNDS)
      , "UPtr", &rect ; PVOID pvAttribute
      , "UInt", size  ; DWORD cbAttribute
      , "UInt")       ; HRESULT

   If er
      DllCall("GetWindowRect", "UPtr", hwnd, "UPtr", &rect, "UInt")

   r := []
   r.x1 := NumGet(rect, 0, "Int"), r.y1 := NumGet(rect, 4, "Int")
   r.x2 := NumGet(rect, 8, "Int"), r.y2 := NumGet(rect, 12, "Int")
   r.w := Abs(max(r.x1, r.x2) - min(r.x1, r.x2))
   r.h := Abs(max(r.y1, r.y2) - min(r.y1, r.y2))
   rect := ""
   ; ToolTip, % r.w " --- " r.h , , , 2
   Return r
}

GetWinClientSize(ByRef w, ByRef h, hwnd, mode) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
; modified by Marius Șucan
    Static prevW, prevH, prevHwnd, lastInvoked := 1
    If (A_TickCount - lastInvoked<95) && (prevHwnd=hwnd)
    {
       W := prevW, H := prevH
       Return
    }

    prevHwnd := hwnd
    If (mode=2)
    {
       r := GetWindowPlacement(hwnd)
       prevW := W := r.w
       prevH := H := r.h
    } Else If (mode=1)
    {
       r := GetWindowBounds(hwnd)
       prevW := W := r.w
       prevH := H := r.h
    } Else 
    {
       VarSetCapacity(rc, 16, 0)
       DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
       prevW := W := NumGet(rc, 8, "int")
       prevH := H := NumGet(rc, 12, "int")
       rc := ""
    }

    lastInvoked := A_TickCount
} 

WinMoveZ(hWnd, C, X, Y, W, H, Redraw:=0) {
  ; WinMoveZ v0.5 by SKAN on D35V/D361 - https://www.autohotkey.com/boards/viewtopic.php?f=6&t=76745
  ; modified by Marius Șucan

  ; If Redraw=2, the new coordinates will be returned
  ; Moves a window to given coordinates, but confines the window within the work area of the target monitor.
  ; Which target monitor? : Whichever monitor POINT (X, Y) belongs to
  ; What if POINT doesn't belong to any monitor? : The monitor nearest to the POINT will house the window.

  Local V := VarSetCapacity(R, 48, 0), TPM_WORKAREA := 0x10000
      , A := &R + 16, S := &R + 24, E := &R, NR := &R + 32

  C := ( C:=Abs(C) ) ? DllCall("SetRect", "Ptr",&R, "Int",X-C, "Int",Y-C, "Int",X+C, "Int",Y+C) : 0
  DllCall("SetRect", "Ptr",&R+16, "Int",X, "Int",Y, "Int",W, "Int",H)
  DllCall("CalculatePopupWindowPosition", "Ptr",A, "Ptr",S, "UInt",TPM_WORKAREA, "Ptr",E, "Ptr",NR)
  X := NumGet(NR+0,"Int")
  Y := NumGet(NR+4,"Int")
  If (Redraw=2)
     Return [X, Y]
  Else 
     Return DllCall("MoveWindow", "UPtr",hWnd, "Int",X, "Int",Y, "Int",W, "Int",H, "Int",Redraw)
}

GetWinParent(hwnd) {
   ; Retrieves a handle to the specified window's parent or owner.
   Return DllCall("GetParent", "UPtr", hwnd)
}

GetMenuItemRect(hwnd, hMenu, nPos) {
    VarSetCapacity(RECT, 16, 0)
    if DllCall("User32.dll\GetMenuItemRect", "UPtr", hwnd, "UPtr", hMenu, "UInt", nPos, "UPtr", &RECT)
    {
       objRect := { left   : numget( RECT,  0, "UInt" )
                  , top    : numget( RECT,  4, "UInt" )
                  , right  : numget( RECT,  8, "UInt" )
                  , bottom : numget( RECT, 12, "UInt" ) }
       rect:= ""
       return objRect
    }

    rect:= ""
    return 0
}

doSetCursorPos(pX, pY) {
  DllCall("user32\SetCursorPos", "Int", pX, "Int", pY)
}

JEE_ClientToScreen(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472

  VarSetCapacity(POINT, 8)
  NumPut(vPosX, &POINT, 0, "Int")
  NumPut(vPosY, &POINT, 4, "Int")
  DllCall("user32\ClientToScreen", "UPtr", hWnd, "UPtr", &POINT)
  vPosX2 := NumGet(&POINT, 0, "Int")
  vPosY2 := NumGet(&POINT, 4, "Int")
}

JEE_ScreenToWindow(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472

  VarSetCapacity(RECT, 16, 0)
  DllCall("user32\GetWindowRect", "UPtr", hWnd, "UPtr", &RECT)
  vWinX := NumGet(&RECT, 0, "Int")
  vWinY := NumGet(&RECT, 4, "Int")
  vPosX2 := vPosX - vWinX
  vPosY2 := vPosY - vWinY
  RECT := ""
}

JEE_ScreenToClient(hWnd, vPosX, vPosY, ByRef vPosX2, ByRef vPosY2) {
; function by jeeswg found on:
; https://autohotkey.com/boards/viewtopic.php?t=38472
  VarSetCapacity(POINT, 8, 0)
  NumPut(vPosX, &POINT, 0, "Int")
  NumPut(vPosY, &POINT, 4, "Int")
  DllCall("user32\ScreenToClient", "UPtr", hWnd, "UPtr", &POINT)
  vPosX2 := NumGet(&POINT, 0, "Int")
  vPosY2 := NumGet(&POINT, 4, "Int")
  POINT := ""
}

MWAGetMonitorMouseIsIn(coordX:=0,coordY:=0) {
; function from: https://autohotkey.com/boards/viewtopic.php?f=6&t=54557
; by Maestr0

  ; get the mouse coordinates first
  If (coordX && coordY)
  {
     Mx := coordX
     My := coordY
  } Else GetPhysicalCursorPos(mX, mY)

  SysGet, MonitorCount, 80  ; monitorcount, so we know how many monitors there are, and the number of loops we need to do
  Loop, %MonitorCount%
  {
    SysGet, mon%A_Index%, Monitor, %A_Index%  ; "Monitor" will get the total desktop space of the monitor, including taskbars
    If (Mx>=mon%A_Index%left) && (Mx<mon%A_Index%right)
    && (My>=mon%A_Index%top) && (My<mon%A_Index%bottom)
    {
       ActiveMon := A_Index
       Break
    }
  }
  Return ActiveMon
}

GetPhysicalCursorPos(ByRef mX, ByRef mY) {
; function from: https://github.com/jNizM/AHK_DllCall_WinAPI/blob/master/src/Cursor%20Functions/GetPhysicalCursorPos.ahk
; by jNizM, modified by Marius Șucan
    Static lastMx, lastMy, lastInvoked := 1
    If (A_TickCount - lastInvoked<70)
    {
       mX := lastMx
       mY := lastMy
       Return
    }

    lastInvoked := A_TickCount
    Static POINT
         , init := VarSetCapacity(POINT, 8, 0) && NumPut(8, POINT, "Int")
    GPC := DllCall("user32.dll\GetPhysicalCursorPos", "Ptr", &POINT)
    If (!GPC || A_OSVersion="WIN_XP")
    {
       MouseGetPos, mX, mY
       lastMx := mX
       lastMy := mY
       Return
     ; Return DllCall("kernel32.dll\GetLastError")
    }

    lastMx := mX := NumGet(POINT, 0, "Int")
    lastMy := mY := NumGet(POINT, 4, "Int")
    Return
}

GetWindowPlacement(hWnd) {
    Local WINDOWPLACEMENT, Result := {}
    NumPut(VarSetCapacity(WINDOWPLACEMENT, 44, 0), WINDOWPLACEMENT, 0, "UInt")
    r := DllCall("GetWindowPlacement", "UPtr", hWnd, "UPtr", &WINDOWPLACEMENT)
    If (r=0)
    {
       WINDOWPLACEMENT := ""
       Return 0
    }
    Result.x := NumGet(WINDOWPLACEMENT, 28, "Int")
    Result.y := NumGet(WINDOWPLACEMENT, 32, "Int")
    Result.w := NumGet(WINDOWPLACEMENT, 36, "Int") - Result.x
    Result.h := NumGet(WINDOWPLACEMENT, 40, "Int") - Result.y
    Result.flags := NumGet(WINDOWPLACEMENT, 4, "UInt") ; 2 = WPF_RESTORETOMAXIMIZED
    Result.showCmd := NumGet(WINDOWPLACEMENT, 8, "UInt") ; 1 = normal, 2 = minimized, 3 = maximized
    WINDOWPLACEMENT := ""
    Return Result
}

SetWindowPlacement(hWnd, x, y, w, h, showCmd:=1) {
    ; showCmd: 1 = normal, 2 = minimized, 3 = maximized
    Local WINDOWPLACEMENT
    NumPut(VarSetCapacity(WINDOWPLACEMENT, 44, 0), WINDOWPLACEMENT, 0, "UInt")
    NumPut(x, WINDOWPLACEMENT, 28, "Int")
    NumPut(y, WINDOWPLACEMENT, 32, "Int")
    NumPut(w + x, WINDOWPLACEMENT, 36, "Int")
    NumPut(h + y, WINDOWPLACEMENT, 40, "Int")
    NumPut(showCmd, WINDOWPLACEMENT, 8, "UInt")
    r := DllCall("SetWindowPlacement", "UPtr", hWnd, "UPtr", &WINDOWPLACEMENT)
    WINDOWPLACEMENT := ""
    Return r
}

GetWindowInfo(hWnd) {
    Local WINDOWINFO, wi := {}
    NumPut(VarSetCapacity(WINDOWINFO, 60, 0), WINDOWINFO, 0, "UInt")
    r := DllCall("GetWindowInfo", "UPtr", hWnd, "UPtr", &WINDOWINFO)
    wi.WindowX := NumGet(WINDOWINFO, 4, "Int")
    wi.WindowY := NumGet(WINDOWINFO, 8, "Int")
    wi.WindowW := NumGet(WINDOWINFO, 12, "Int") - wi.WindowX
    wi.WindowH := NumGet(WINDOWINFO, 16, "Int") - wi.WindowY
    wi.ClientX := NumGet(WINDOWINFO, 20, "Int")
    wi.ClientY := NumGet(WINDOWINFO, 24, "Int")
    wi.ClientW := NumGet(WINDOWINFO, 28, "Int") - wi.ClientX
    wi.ClientH := NumGet(WINDOWINFO, 32, "Int") - wi.ClientY
    wi.Style   := NumGet(WINDOWINFO, 36, "UInt")
    wi.ExStyle := NumGet(WINDOWINFO, 40, "UInt")
    wi.Active  := NumGet(WINDOWINFO, 44, "UInt")
    wi.BorderW := NumGet(WINDOWINFO, 48, "UInt")
    wi.BorderH := NumGet(WINDOWINFO, 52, "UInt")
    ;wi.Atom    := NumGet(WINDOWINFO, 56, "UShort")
    ;wi.Version := NumGet(WINDOWINFO, 58, "UShort")
    WINDOWINFO := ""
    Return wi
}

Edit_ShowBalloonTip(hEdit, Text, Title := "", Icon := 0) {
    Local EDITBALLOONTIP
    NumPut(VarSetCapacity(EDITBALLOONTIP, 4 * A_PtrSize, 0), EDITBALLOONTIP)
    NumPut(&Title, EDITBALLOONTIP, A_PtrSize, "Ptr")
    NumPut(&Text, EDITBALLOONTIP, A_PtrSize * 2, "Ptr")
    NumPut(Icon, EDITBALLOONTIP, A_PtrSize * 3, "UInt")
    SendMessage 0x1503, 0, &EDITBALLOONTIP,, ahk_id %hEdit% ; EM_SHOWBALLOONTIP
    Return ErrorLevel
}

SetWindowRegion(hwnd, x:=0, y:=0, w:=0, h:=0, r:=1) {
  hR1 := DllCall("gdi32\CreateRoundRectRgn", "Int", x, "Int", y, "Int", w, "Int", h, "Int", r, "Int", r, "Ptr")
  Result := DllCall("user32\SetWindowRgn", "UPtr", hwnd, "UPtr", hR1, "UInt", 1)
  DllCall("gdi32\DeleteObject", "Ptr", hR1)
  Return Result
}

