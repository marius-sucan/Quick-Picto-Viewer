# Folders tree panel audit, 2026-11-18

Scope: `PanelFoldersTree()` (:30613), the panel it builds («Folders tree view», F4), its two
buttons, its status bar, its keys, its menu `folderTreeContextMenu()` (:31585), its drag and
drop, and every function those reach, as far as a panel action reaches them. Line numbers are
`quick-picto-viewer.ahk` on `development` at `7802a22`. The audit changed no code.

Sixteen findings and a section of small things. Each one says how it was checked: **run**
means a script ran it under headless Wine, on AutoHotkey_H 1.1.33.10; **read** means it
follows from the code and was not run. Two facts were run (findings 11 and 16); everything
else is read. Nothing was run on Windows, and the application itself was not run for this
audit.

## Terms

- **The tree**: this panel, the window `fdTreeGuia`. F4, the toolbar button, a click on the
  status bar and «Show folders tree panel» in the menus open it (`MenuPanelFoldersTree()`
  :30606).
- **Element**: an item of the tree. A drive is labelled `C:\`, every other element `\name`;
  an element's path is the labels from the top down, joined (`folderTreeGetSelectedPath()`
  :31158). **Drive element**: a top element such as `C:\`.
- **Selected element**: the one every action works on (`TV_GetSelection()`).
- **The menu**: the tree's own menu, `PVfdTree`. A right-click on an element, the Menu key
  and the «>» button («Menu options») show it.
- **The «`\\`» button**: the first button under the tree (tooltip «Folder tree»). It runs
  `invokeFoldersListerMenu()` (:73094), the menu of the current folder's siblings,
  sub-folders and parents, which Shift+F4 opens in the main window
  (`chainInvokerFoldersListMenu()` :69305). With no folder to show, it shows the menu instead
  (`folderTreeMiniBtn()` :30683).
- **Current folder**: the folder opened in QPV for a plain list, otherwise the folder of the
  current file.
- **List tree** and **no-list tree**: what F5 (`FolderTreeRepopulate()` :31365) builds. With a
  list loaded: the current folder's drive, its parents, its siblings and its sub-folders
  (:31431-31510). With none: every ready drive with its first level of folders, then the
  recent folders (:31381-31429).
- **Index**: QPV's files list, `resultedFilesList`. **Plain list**, **.SLD list**,
  **database** (an .SLDB list), **seed folders list** (`DynamicFoldersList`) and **folders
  list** (`newStaticFoldersListCache`, the Ctrl+U panel): as in
  `seed-folders-panel-audit-2026-11-15.md`.
- **Shared helper**: a function the tree calls that other features call too. Each finding on
  one names the other callers, so that a fix is not made for the tree alone.

## Summary

| # | Finding | Harm | Checked | Shared with |
|---|---------|------|---------|-------------|
| 1 | «Scan recursively?»: the answer «No» is ignored; after a failed open a .SLD list or a database is not reopened | high | read | six other callers of `tryOpenGivenFolder()` |
| 2 | The «`\\`» button's folder items replace an edited image, a modified .SLD list or a selection without the questions «Open folder now» asks | high | read | Shift+F4 menu |
| 3 | Shift and Ctrl with Enter or a double-click do the reverse of the menu's hints | medium | read | the folders list panels' open code |
| 4 | No list loaded: Shift+F3, or a drop on the main window with Shift held, opens a new QPV instance | medium | read | — |
| 5 | «Rename folder» looks for the new name inside the folder instead of beside it | medium | read | omnibox F2 |
| 6 | «Rename folder» with «Perform search and replace»: the opened folder, the seed folders list and the folders list keep the old path | medium | read | omnibox F2 |
| 7 | A folder dropped on a missing folder: the destination is recreated, then nothing is copied or moved | medium | read | the omnibox's drags |
| 8 | «Copy/Move selected file(s) into...» and file drops: a destination of four characters or fewer opens the quick file actions panel | medium | read | the omnibox's copy and move |
| 9 | Files Alt+dragged from the main window: Alt still held half a second after the drop opens Explorer instead | low | read | drops on the omnibox |
| 10 | «Import images into the list» moves the current file to the end of the list, also when nothing was imported | low | read | — |
| 11 | A label whose case differs from the disk's: the tree lists the folder twice (every database list) | medium | run (part), read | — |
| 12 | A drag between two sibling elements: the confirmation box swaps source and destination | medium | read | — |
| 13 | A folder moved by a drag stays in the tree at its old place | low | read | — |
| 14 | Ctrl+X and Ctrl+C put a whole drive on the clipboard | low | read | — |
| 15 | The «`\\`» menu: the «more folders» notes land in the siblings submenu, and the count is one short | low | read | Shift+F4 menu |
| 16 | «Create new folder»: a name the filter changes can land on an existing folder, listed twice | low | run (part), read | omnibox F7 |
| 17 | Small things (nine points) | low | read | |

---

## 1. «Scan recursively?»: the answer «No» is ignored

`tryOpenGivenFolder()` :73293, reached by «Open folder now», Enter and a double-click
(`folderTreeDefaultAction()` :30776)

```ahk
If !FolderExist(oldFolderu)
   msgResult := msgBoxWrapper(appTitle ": Confirmation", "... QPV found no supported image files in the folder.`n`nWould you like to recursively scan the given folder for supported image files?", 4, 0, "question")
Else msgResult := "Yes"

If (msgResult="Yes" || !FolderExist(oldFolderu))
{
   coreOpenFolder(thisFolder, 0, 0, 0, 1)
   CurrentSLD := thisFolder
}
```

(:73315-73323)

The folder is opened first without its sub-folders (:73311). When it holds no image file
directly:

- if the previous current folder exists (a plain list was open), there is no question: the
  folder is scanned with its sub-folders at once;
- otherwise the question is asked, and both answers scan with the sub-folders: the question
  comes only when `!FolderExist(oldFolderu)` is true, and that same test is the second half of
  the condition. «Otherwise» means no list loaded (`oldFolder` is blank), a .SLD list or a
  database open (`CurrentSLD` is then a file, and `FolderExist()` wants a folder, :44359), or
  a previous folder that is gone.

Example (read): no list loaded, so the no-list tree shows every drive. A double-click on `D:\`,
a drive whose root holds no image: the question comes, «No», and the whole drive is scanned
with all its folders.

When the scan with sub-folders finds nothing either (:73327-73334), a plain folder that was
open is opened again; a .SLD list or a database is not (`FolderExist()` of the list file is
false), and the welcome screen comes instead. A database was closed at the start (:73304-73305),
before anything was found.

Shared helper: `tryOpenGivenFolder()` also opens a folder given on the command line with a
leading `|` (`initializeAppWithGivenArguments()` :2469; the seed folders panel's «With a new QPV
instance» sends one for an entry scanned without its sub-folders, :97504), the omnibox's «Open
folder» (:27133), the sibling and parent
navigation (`FileExploreUpDownLevel()` :65090, `FileExploreSiblingsNav()` :65172), the
«Sub-folders» items (`folderzNavInvokeSubs()` :73290) and the folders list panels' «Open folder
now» (`BtnPanelManageFoldersActus()` :97526).

Correction: `If (msgResult="Yes")`. A list file could be reopened with `OpenSLD()` where
`coreOpenFolder(oldFolder, …)` reopens a folder. Whether the scan without a question should stay
when a folder was open is decision 2.

## 2. The «`\\`» button's folder items open folders without the save and selection questions

`invokeFoldersListerMenu()` :73094; its items run `folderzNavInvokeSib()` :73356,
`folderzNavInvokeSubs()` :73267, `folderzNavInvokeParents()` :73364 and the four
`MenuFolderExplorer…()` functions (:73251-73265)

The tree's own «Open folder now» asks three questions before it opens anything (:30767-30774):

```ahk
If askAboutFileSave(" and the selected folder will be opened")
   Return

If askAboutSlidesListSave()
   Return

If askAboutFilesSelect("discard it")
   Return
```

The «`\\`» menu's items reach `tryOpenGivenFolder()` through `FileExploreSiblingsNav()` (:65093),
`FileExploreUpDownLevel()` (:64988) or directly (:73290), and none of them asks any of the
three (read: `FileExploreSiblingsNav()`, `FileExploreUpDownLevel()`, `folderzNavInvokeSubs()`,
`tryOpenGivenFolder()` and `coreOpenFolder()` :65185 call none of them). The «Sibling folders», «Sub-folders» and «Breadcrumb folders hierarchy» submenus are
built for every kind of list, in the image view too (:73113-73177, attached at :73191, :73201 and
:73214); only «Breadcrumb deeper/higher level» and «Open next/previous sibling» need a plain list
(:73202, :73215).

What happens (read): an image edited and not saved, a .SLD list modified and not saved, a
selection large enough for «Discard selection» to ask (25 files or more, with at least 25 left
out, in a list of more than 150, :67222): one click on a sibling or a sub-folder replaces them,
without «Save image», «Save files list» or «Discard selection».

Shared: the same menu is Shift+F4 in the main window («Folders explorer menu for active file»,
:68873). The main window's keys for the sibling moves, Alt+Page Up and Alt+Page Down, work only
in the thumbnails view on a plain list (:2225-2238).

Correction: ask the three questions before these items open a folder, at one place that all of
them pass through before `tryOpenGivenFolder()`.

## 3. Shift and Ctrl do the reverse of the menu's hints

`folderTreeDefaultAction()` :30728; the menu's «Open» submenu :31603-31608

```ahk
Else If (GetKeyState("Shift", "P") || (modus="anew" && g="yo") )
   z := 2   ; a new QPV instance
Else If (GetKeyState("Ctrl", "P") || (modus="explorer" && g="yo"))
   z := 1   ; Explorer
```

(:30736-30739; the comments are not in the code)

```ahk
kMenu("PVopenF", "Add", "In Explorer`tShift+Enter", "folderTreeOpenInExplorer")
kMenu("PVopenF", "Add", "With a new QPV instance`tCtrl+Enter", "folderTreeOpenInNewInstance")
```

(:31605-31606)

Enter reaches `folderTreeDefaultAction()` through the hidden default button (:30673), a
double-click directly (:30875-30878). Both read the keys held down: Shift opens a new QPV
instance, Ctrl opens Explorer. The menu says the reverse. The two menu items do what they say:
they pass `anew` and `explorer`.

A double-click with Shift or Ctrl takes this path for certain (read). Whether the dialog manager
hands Shift+Enter and Ctrl+Enter to the hidden default button was not checked.

Elsewhere: the main window's menus give Ctrl+Enter to «Open file in a new QPV instance» (:68035,
:70019); the folders list panels' `BtnPanelManageFoldersActus()` (:97465) reads Shift and Ctrl as
the tree does, and their menu shows no key for these two items (:94114-94116). Which side to
change is decision 1.

## 4. No list loaded: Shift+F3, or a drop with Shift held, opens a new QPV instance

`folderTreeAppendFiles()` :32045, reached by F3 (:30855), the menu's «Import images into the
list» and a drop of an element on the main window (:30985-30989)

```ahk
If (maxFilesIndex<1 || !CurrentSLD)
{
   folderTreeDefaultAction()
   Return
}
```

(:32046-32050)

With no list loaded the import falls back to «Open folder now», and `folderTreeDefaultAction()`
reads Shift and Ctrl (finding 3). Shift is how the user asks the import to scan the sub-folders:
F3 reads it (:32062-32063), and the drag's tooltip says «Hold SHIFT for recursive scanning»
(:30940). So, with no list loaded (read):

- Shift+F3, or a drop on the main window with Shift held: a new QPV instance opens the folder;
- Ctrl+F3, or a drop with Ctrl held: Explorer opens.

The tooltip says «Drop folder here to import it into the current list» while there is no list
(:30941).

Correction: let the fallback open the folder without reading the keys, and decide whether Shift
should then mean a scan with the sub-folders.

## 5. «Rename folder» looks for the new name inside the folder

`UIcoreFolderRename()` :31972, reached by F2 (:30852) and the menu

```ahk
If FolderExist(thisFolder "\" newFileName)
   Return msgBeepTimer("WARNING: A folder with the given name already exists:`n" thisFolder "\`n" newFileName "\", 0)

oldPath := SubStr(thisFolder, 1, InStr(thisFolder, "\", 0, -1) - 1)
FileMoveDir, % thisFolder, % oldPath "\" newFileName, R
```

(:31991-31995)

The rename puts the folder beside itself (`oldPath "\" newFileName`), but the check looks
inside it. Two results (read):

- renaming `D:\pics\2024` to `old` while `D:\pics\2024\old` exists is refused: «A folder with
  the given name already exists»;
- renaming it to `old` while `D:\pics\old` exists passes the check; `FileMoveDir` with `R` fails
  when the destination exists (AutoHotkey's documentation), and the message is «ERROR: An
  unknown error occurred renaming the folder».

Shared helper: the omnibox's F2 (`omniBoxFolderRename()` :27203).

Correction: check `oldPath "\" newFileName`, and let a change of case alone through (the folder
itself passes that test).

## 6. «Rename folder» with «Perform search and replace in current list»: the lists keep the old path

`UIcoreFolderRename()` :31996-32000 → `SearchAndReplaceThroughIndex()` :98632

The tick runs `SearchAndReplaceThroughIndex(old "\", new "\", 0, 1)` (:31999), which rewrites
the paths of the index and, in a database, the `images` table. Nothing else follows the folder
(read):

- `CurrentSLD`: the search and replace saves it and puts it back unchanged (:98649, :98831). On a
  plain list it names the opened folder, so after renaming that folder the tree's F5 builds the
  old name again, in bold, beside the new one: the old name is not found on the disk and is added
  anyway, as a folder hidden by access rights (:31486-31488).
- The seed folders list (`DynamicFoldersList`): on a plain list it is the opened folder itself
  (`coreOpenFolder()` :65211); on a .SLD list or a database, the entry of the renamed folder and
  those of the folders inside it keep the old path, and the next rescan finds them missing.
- The folders list (`newStaticFoldersListCache`, and the `staticfolders` table of a database):
  its rows keep the old path, and the Ctrl+U panel shows them as missing.
- In a database the captions and audio notes stay on the old paths: already «Seen in passing» F
  of `static-folders-panel-audit-2026-11-10.md`.

The two list panels' «Rename index entry» (`PanelRenameStaticFolder()` :98325) rewrite the seed
folders list or the folders list along with the index (:98411-98451). The tree renames the folder
on the disk as well, so the lists should follow; how far is decision 3.

With no list loaded the tick is offered too, and ticked it runs on the empty index: «Finished
updating the files list, 0 records were modified».

Shared helper: the omnibox's F2.

## 7. A folder dropped on a missing folder: recreated, then nothing copied or moved

`UIcoreFolderPasteFoldersInto()` :31817, reached by a drag inside the tree (:31043), from the
tree to the omnibox (:31009) and by the omnibox's drags (:42623, :42644)

A drop passes the action in `gactu` («[_COPY_]» or «[_MOVE_]»), which is kept in `msgResult`
(:31819-31824). When the destination folder is missing, the same variable receives the answer
to «It seems to no longer exist. Would you like to recreate it? By choosing yes, QPV will perform
the intended folder action» (:31828-31841):

```ahk
If (StrLen(thisFolder)>1)
   msgResult := msgBoxWrapper(appTitle ": Confirmation", "Destination folder: " thisFolder "\`n`nIt seems to no longer exist. ...", 4, 0, "question")

If (msgResult="Yes")
{
   FileCreateDir, %thisFolder%
```

`msgResult` is now «Yes». A drop does not ask «Copy | Move» (that question is for the menu's
paste, :31854-31859), so the test that picks the action finds neither word (:31863-31874) and
returns: the folder is recreated, empty, nothing is copied or moved, and no message says so
(read).

A missing destination stays in the tree after a folder was deleted or moved outside QPV. The
menu does not offer «Paste folder(s) into...» on one (:31631-31639), and the menu's paste asks
«Copy | Move» after the recreate question, so it works.

Correction: keep the drop's action in a variable of its own.

## 8. «Copy/Move selected file(s) into...»: a short destination opens the quick file actions panel

`triggerQuickFileAction()` :47220, reached by the menu's two items (`FolderTreeMenuCopyFiles()`
:31671 and the move twin) and by files Alt+dragged from the main window onto an element
(:9833-9859)

```ahk
If (StrLen(UsrEditFileDestination)<5)
{
   PanelQuickMoveConfigure()
   Return
}
```

(:47279-47283)

The test was made for the six destinations of the quick file actions: a blank or short one means
«not set up yet». For the tree (`thisVar=7`, :47244-47261) the destination is the selected
element's path, and a real folder of four characters or fewer fails it: `D:\a`, `E:\1`, or a
drive root `D:\` (three). Instead of the copy, the quick file actions panel opens, and opening it
closes the tree (`createSettingsGUI()` :28119). The menu does not offer the two items on a drive
element (:31598), but a drop of files on one reaches the test. The destination is recorded as the
last move folder and among the recent destinations before the test (:47256-47260). (read)

The same function also returns without a word while a slideshow runs (the first call only stops
it, :47225-47226), within a quarter of a second of its last call, and while a panel is open
(:47228-47233). (read)

Shared helper: the omnibox's «Copy/Move selected file(s)» and its drop (`omniBoxFolderCopyFiles()`
:27265, `thisVar=8` :47262-47277).

Correction: for destinations 7 and 8, test that the folder exists instead of its length.

## 9. Files Alt+dragged from the main window: Alt still held opens Explorer

The main window's thumbnails click handler (Alt + drag, :9712) → `SetTimer, % func2exec, -500`
(:9859) → `triggerQuickFileAction()` :47285-47297

```ahk
altState := GetKeyState("Alt", "P")
ctrlState := GetKeyState("Ctrl", "P")
lastInvoked := A_TickCount
If (altState=1 && ctrlState!=1)
{
   Try Run, "%UsrEditFileDestination%"
   UsrEditFileDestination := ""
   Return
}
```

A drag of files from the main window into the tree starts with Alt held (:9712). The copy or
move runs from a timer half a second after the drop, and reads Alt again: if it is still down,
Explorer opens on the destination and nothing is copied; with Ctrl+Alt, a new QPV instance opens
instead. With the confirmation box (shown by default) the user answers it first and the timer
starts afterwards; once «Do not ask again in this session» is ticked there is no box. (read; it
depends on how long Alt is held)

Shared: files Alt+dragged onto the omnibox (`omniBoxFolderCopyFiles()` :27265).

Correction: let the drop tell `triggerQuickFileAction()` to skip the Alt and Ctrl tests, which
are meant for the keys 1 to 7.

## 10. «Import images into the list» moves the current file to the end of the list

`folderTreeAppendFiles()` :32045-32070

```ahk
If GetKeyState("Shift", "P")
   addNewFolder2list(linea, "yes", "recursive")
Else
   addNewFolder2list(linea, "yes", modus)
; SoundBeep 900, 100
ResetImgLoadStatus()
currentFileIndex := (maxFilesIndex<2) ? maxFilesIndex : maxFilesIndex - 1
dummyTimerDelayiedImageDisplay(50)
```

(:32062-32069)

`addNewFolder2list()` (:66451) returns «cancel» for Cancel in the scan question
(`askFolderImportMode()` :66434-66442, then :66470-66471) and for «No» to «The folder seems to be
already indexed» (:66496-66506), returns nothing after Cancel in «Save image» (:66466-66467), and
returns «rescan» when the folder was rescanned instead. The tree does not look at it: the current
file becomes the next-to-last of the list every time, so a cancelled import loses the user's
place. After an import it shows the next-to-last of the new files. (read)

Correction: move the current file only after an import; the first new file would show what came
in.

## 11. A label whose case differs from the disk's: the tree lists the folder twice

`folderTreeScanSubbies()` :32102, `FolderTreeFindActiveFile()` :31182, `FolderTreeRepopulate()`
:31365, `iterateFDtreeView()` :31328

A database keeps its paths in lower case (`addSQLdbEntry()` :34119-34120), and the list tree
takes the drive and parent labels from the current file's path (:31446-31459). In a database the
tree therefore reads `d:\` → `\photos` → …, while the disk says `Photos`. Two things then go
wrong.

**a) Space, «Scan for sub-folders», and the rescans after a paste or a drop.**
`folderTreeScanSubbies()` keeps the children that have children of their own, with their label as
key (:32141-32150), and skips those names when it reads the disk (:32171). The keys are held in a
`hashTable` (lib/hashtable.ahk), whose `hasKey()` is case-sensitive (run: after
`h["photos"] := 1`, `h.hasKey("Photos")` is 0, while an AutoHotkey object answers 1). So the
disk's `Photos` is added beside the tree's `\photos`: two elements, one with the sub-tree, one
without (read).

Example (read): a database with images in `D:\Photos\2024`. F4, select `d:\`, Space: `\photos`
and `\Photos` side by side.

F9 (`FolderTreeFindActiveFile()`) keeps its children the same way (:31264-31270, :31299).

**b) A capital letter outside A-Z.** `=` folds A to Z only (the seed folders audit's finding 4),
while the database's lower case folds É, Ș and Ä too. In a database the current folder `été` does
not match the disk's `Été` (:31480): F5 and the opening show the folder twice, the disk's `\Été`
and a bold `\été` that holds the sub-folders (:31486-31488). F9's `iterateFDtreeView()` compares
the same way (:31340) and adds a second chain. (read)

Plain and .SLD lists show the same when a path is stored in another case than the disk's: a
folder renamed in case only, a path typed in the omnibox. (read)

Correction: compare, and key the `hashTable`, in lower case (`Format("{:L}")`), as the seed
folders panel does since `7c031cb`.

## 12. A drag between sibling elements: the confirmation box swaps source and destination

`FolderTreeResponder()` :31015-31038

```ahk
src := folderTreeGetSelectedPath(c)
dest := folderTreeGetSelectedPath(nc)
If (TV_GetParent(nc) = TV_GetParent(c))
{
   TV_GetText(sr, nc)
   TV_GetText(dst, c)
}
```

(:31018-31023)

`c` is the element dragged, `nc` the one it was dropped on. For two siblings, the box («Please
confirm with Yes that this was not accidental. Source: … Destination: …», :31032) shows the
destination as «Source» and the dragged folder as «Destination». The action itself uses `src` and
`dest` and is right. The box is there to catch an accidental drop, and it describes the move
backwards. (read)

Two drive elements are siblings too: the box shows them swapped, then the copy is refused, since
drives are never copied (:31884).

Correction: `TV_GetText(sr, c)` and `TV_GetText(dst, nc)`.

## 13. A folder moved by a drag stays in the tree at its old place

`FolderTreeResponder()` :31040-31046, `UIcoreFolderPasteFoldersInto()` :31899

After a move inside the tree, the selected element, the destination, is scanned again, twice:
inside `UIcoreFolderPasteFoldersInto()` (:31899) and at :31044-31045. The folder then shows under
its new parent, but its old element is never removed. The tree lists the folder in both places,
and every action on the old one says the folder no longer exists. After a move from the tree to
the omnibox, the rescan at :31899 runs on the dragged element, selected again while the pointer
was over the omnibox (:30949); its folder is gone, so it loses its children and stays. (read)

Correction: after a move, delete the dragged element.

## 14. Ctrl+X and Ctrl+C put a whole drive on the clipboard

`KeyboardResponder()` :880-883 → `folderTreeCutCopyFolder()` :31926 →
`UIcoreFolderCutCopyExplorer()` :31937

The menu offers «Cut folder» and «Copy folder» on folders only (its folder actions are skipped for
a label holding `:`, :31598), and `folderTreeIsDriveRoot()` says «entire drives must never be
renamed, deleted or moved» (:31575-31576). The keys do not test it: on a drive element, Ctrl+X
puts `D:\` on the clipboard as a cut and Ctrl+C as a copy, and the message says «the folder can
now be pasted in any file manager». QPV's own paste skips drives (:31884); what Explorer does with
a pasted drive was not checked. (read)

Correction: `If folderTreeIsDriveRoot(thisFolder) Return` in `folderTreeCutCopyFolder()`. F3, F7,
F12, Enter and `;` also work on a drive element, while the menu offers none of them there
(decision 5).

## 15. The «`\\`» menu: the «more folders» notes land in the wrong submenu, and the count is one short

`invokeFoldersListerMenu()` :73113-73177

Each submenu lists 200 folders and then a note that opens the tree:

- siblings: `"and " sibsObj.Count() - A_Index " more folders"` runs at `A_Index` 201, so with 250
  siblings it says «and 49 more folders» for the 50 not listed (:73121-73123);
- parents: the note is added to the siblings submenu `PVmFsibs` (:73136); more than 200 levels do
  not occur with ordinary paths;
- sub-folders: 201 are listed before the test (:73169-73170 count after the `Add`), and the note
  «... more folders can be listed» goes to the siblings submenu as well (:73172); with no siblings
  that submenu is never attached, and the note is never seen.

From the tree's own button, the note only shows the tree again (`PanelFoldersTree()` with the tree
open, :30635-30640). (read)

Shared: Shift+F4 in the main window.

Correction: `Count() - 200`, `PVmFparents` and `PVmFsubs`, and the sub-folders test before the
`Add`.

## 16. «Create new folder»: a name the filter changes can land on an existing folder

`UIcoreFolderNew()` :31679, reached by F7 (:30861) and the menu; `folderTreeCreateFolder()`
:31724-31732

```ahk
newFileName := Trimmer(msgResult.edit)
If FolderExist(thisFolder "\" newFileName)
   Return msgBeepTimer("WARNING: A folder with the given name already exists:`n" thisFolder "\`n" newFileName "\", 0)

newFileName := filterFileName(newFileName, 0)
If !newFileName
   Return msgBeepTimer("WARNING: Incorrect folder name given.")

FileCreateDir, %thisFolder%\%newFileName%
If !ErrorLevel
{
   Return 1
```

(:31683-31694)

The check runs on the name as typed; `filterFileName()` then trims leading and trailing dots and
commas (:47910-47911). `,photos` or `.photos` beside an existing `photos` passes the check and
becomes `photos`, and `FileCreateDir` on an existing folder reports success (run: ErrorLevel 0 the
second time). The tree then adds a second `\photos` (:31729), and nothing told the user the folder
existed. With trailing dots, Windows drops them from the path, so the check finds the existing
folder (not run).

Shared helper: the omnibox's F7 (`omniBoxFolderCreateNew()` :27160).

Correction: filter first, then check. The filter also turns a requested `.config` into `config`
without a word.

## 17. Small things

a. **Rename does not sort.** `TV_Modify(c, "Select Vis Sort", "\" newFileName)` (:31967) sorts the
   children of the renamed element (that is AutoHotkey's `Sort` option), not the element among its
   siblings: it keeps its old place.

b. **«Paste clipboard file(s) into...» brings the tree back only after Cancel.**
   `PasteFilesIntoGivenFolder()` returns 1 for Cancel (:32228) and nothing after a paste (it ends
   with `msgBeepTimer()` at :32391), and `folderTreePasteClippy()` activates the tree when the result
   is true (:32201-32203).

c. **«Scan for sub-folders» can stay on a missing folder.** The item is removed by its label,
   ``&Scan for sub-folders`tSpace`` (:31636). `kMenu()` drops the key from a label when the user's
   own shortcuts give that key to another function (:71547-71561), and the removal then misses.

d. **The «7» and «Shift+7» hints** of «Copy/Move selected file(s) into...» (:31628-31629): in the
   tree, 7 goes to the tree's own type-ahead search; in the main window, 7 runs the copy only with
   the quick file actions option on (`allowUserQuickFileActions`, off by default; :2052-2060,
   :47222).

e. **Alt+D opens the selected folder.** The hidden default button is labelled «&Default» (:30673),
   so its mnemonic runs «Open folder now».

f. **«Show folder details» on a folder with no images and no sub-folders** shows its parent's path
   instead of its counts: the counts are shown only when one is not zero (`If (dirs || sizu)`
   :31127).

g. **«Open folder now» on a missing folder** asks about the edited image, the list and the
   selection (:30767-30774), and only then finds the folder gone (`tryOpenGivenFolder()`
   :73297-73302).

h. **The rebuild test** `thisSize := 300 + PrefsLargeFonts + uiUseDarkMode` (:30625) gives 301 for
   large fonts in light mode and for normal fonts in dark mode: if both settings change while the
   tree is hidden, it comes back with the old look. A change of the large font size
   (`LargeUIfontValue`) is not in the test either.

i. **«Paste folder(s) into...» with no folder found** shows the whole clipboard text in its warning
   (:31904).

## Decisions to make before fixing

1. **Shift and Ctrl** (finding 3): keep the code (Shift = new instance, Ctrl = Explorer, as the
   folders list panels do) and change the hints, or keep the hints (Ctrl+Enter = new instance, as in
   the main window's menus) and swap the code?
2. **The scan with sub-folders without a question** (finding 1): when a plain folder was open and
   the new folder holds no image directly, `tryOpenGivenFolder()` scans it with its sub-folders
   without asking. Keep, or ask every time? Six other callers share it.
3. **What the rename's tick carries** (finding 6): the opened folder (`CurrentSLD`), the seed folders
   list, the folders list (in a database its tables, with the captions and audio notes), or a part of
   these? And should the tick be offered when no list is loaded?
4. **The panel's own options in the menu**: «Show folder details», «Collapse/expand entire folder
   tree», «Large UI fonts», «Dark mode» and «Close panel» are in the menu only when no element, a
   drive element or a missing folder is selected (`addBonus`, :31598-31657; this split dates from
   `e0b347a`, v5.6.7). With a folder selected, which is almost always, the «>» button («Menu
   options») shows the folder actions alone, and «Dark mode» and «Close panel» can then be reached
   only by selecting a drive. The «`\\`» button offers three of them when a list is loaded
   (:73233-73244). Show them always, for example in a submenu?
5. **Drive elements**: the menu offers no folder action on a drive (:31598), while the keys F3
   (import), F7 (create a folder), F12 (properties), Enter (open) and `;` (omnibox) work on one, and
   Ctrl+X and Ctrl+C too (finding 14). Which actions should a drive get, in the menu and by key?
6. **The protected folder and «Delete folder»**: the protection makes the file deletions skip the
   folder's files (`batchFileDelete()` :40553-40566, `InListMultiEntriesRemover()` :33973-33982).
   «Delete folder» (Delete, F8) sends the protected folder, or any folder that holds it, to the
   Recycle Bin after the usual question (:31776-31797), and the menu offers «Set as the protected
   folder» a few lines below it. Refuse, warn, or leave as now?
7. **Private mode**: the panel warns that it does not work in private mode (:30633). Turning private
   mode on leaves an open tree showing its folder names (`TogglePrivateMode()` :73632 does not touch
   it), F5 then does nothing without a word (:31372-31373), and a tree hidden and shown again shows
   what it held. Clear it, close it, or keep the warning as the answer?
8. **The tree's window position and size**: the first opening and every rebuild (after «Large UI
   fonts» or «Dark mode» from the tree's menus) place the tree at the last settings panel's position
   (`prevSetWinPosX/Y` :30675, recorded by `CloseWindow()` :99458-99459) or in the middle of the
   screen, at its default size. Remember the tree's own?
9. **The «Folder tree: COLLAPSED» notice**: every no-list build (the opening on the welcome screen,
   F5) and every «View list as a folders tree» from the two list panels shows it, because
   `FolderTreeRepopulate()` calls `folderTreeExpandCollapseAll("collapse")` (:31424 → :32099).
   Silence it there?
10. **The index after «Delete folder» or a drag move**: the index keeps the entries of a folder that
    the tree deleted or moved. Leave them, as after a deletion in Explorer, drop them, or rewrite
    them after a move?

## Unverified leads

These follow from the code but depend on a runtime state that was not reproduced. Each needs a run
before any fix.

- **A. Menus refused while an animation or a slideshow plays.** Space, F5, F9, the rescans after a
  drop or a paste, and «Show folder details» call `doStartLongOpDance()`, which sets `imageLoading`
  and `runningLongOperation` (:35560-35561). `ResetImgLoadStatus()` (:75580) clears them only
  through `uiChangeMcursor("normal-extra")` (lib/module-interface.ahk:1717-1720), which returns at
  once while `animGIFplaying=1` or `slideShowRunning=1` (lib/module-interface.ahk:1711-1712). The
  tree stops playback when it opens (:30619), but the main window can start it again while the
  tree is open. If nothing else clears the two flags during playback, `showThisMenu()` refuses
  every menu (:71676-71677) and
  `PreProcessKbdKey()` runs no shortcut (:602) until playback stops; a navigation key stops the
  animation (:12398-12403), which would end it. Claims of this kind, about two threads, were wrong
  before (finding 11 of `review-selected-files-audit-2026-11-09.md`), so this needs the real route.
- **B. Network paths.** `folderTreeNormalizePath()` (:31568-31573) turns `\\server\share\dir` into
  `server\share\dir`. The list tree then falls back to `FolderTreeFindActiveFile()` (:31436-31441),
  which shows `server\` → `\share` → `\dir`, and every action gets a relative path, which Windows
  resolves against QPV's working folder (`SetWorkingDir` :69). F7 on such an element offers to
  recreate it (:31708-31721), and would create `server\share\dir` inside QPV's folder. Needs a share.
- **C. Shift+Enter and Ctrl+Enter** (finding 3): whether the dialog manager hands them to the hidden
  default button was not run.

## Seen in passing

Outside the panel's own code, found while tracing its actions.

- **A. The main window's Alt+drag over the tree selects every row of the omnibox.** In the
  thumbnails click handler (:9611), the drag's tree branch calls `LV_Modify(initialRow, "select")`
  (:9757). `initialRow` exists only in the omnibox's handler (:42517); here it is blank, which
  counts as row 0, every row. With the omnibox open in folder mode, the default window there is the
  omnibox's (:9714-9716), so hovering the tree selects all its rows. The tooltip says «Move or copy
  folder into another one» while files are dragged (:9758).
- **B. A plain list grown by imports is replaced without a question.** `askAboutSlidesListSave()`
  (:65471) asks only for a .SLD list and the favourites; a plain list that the tree's F3 grew is
  replaced by any open (finding 1's callers) without a word.
- **C. The comment `; F3` on `c=186`** (:30858): the key is `;` (VK_OEM_1), which opens the omnibox
  at the element.

## Checked and found correct

- «Cut folder» and «Copy folder» tell themselves apart by the menu item's name: `C&ut…` holds «cut»
  once the `&` is removed, `C&opy…` does not (:31938); Ctrl+X and Ctrl+C pass «cut» and «copy»
  (:880-883).
- «Set as the protected folder» protects the selected folder itself: `zPlitPath()` returns an
  existing folder's path whole (:60303-60311); the check mark compares in lower case (:31620).
- Rename, Delete and the drags refuse a drive element (`folderTreeIsDriveRoot()` :31575; the paste
  skips drives, :31884).
- The three drag routes keep «Do not ask again» in a `Static` (:9611, :30827, :42450).
- The message box results compared with «delete», «Yes» and «Copy» are the button texts without
  `&` (lib/msgbox2.ahk:469).
- The quick search lists neither the tree's menu nor the «`\\`» menu's items: `buildQuickSearchMenus()`
  (:43081) builds the main menus, and the «`\\`» menu is built only when it is shown
  (`invokeFoldersListerMenu()` is called from :2088, :30684, :69307 and :105532-105534). From the
  quick search the tree is reached through «Show folders tree panel» (`MenuPanelFoldersTree()`) and
  «Folders explorer menu for active file» (`chainInvokerFoldersListMenu()` :69305, which shows the
  «`\\`» menu). In that menu, «Copy folder tree path» passes its name, which holds «copy» (:30691).
- `FolderExist("C:")` is the root of the drive (:44356-44357), so drive elements open and scan.
- The «Sub-folders» items carry the index of a `Loop, Files` over files and folders, and
  `folderzNavInvokeSubs()` counts the same way (:73161-73168, :73277-73284): the right folder opens,
  though the numbers skip the files.
- `MsgBox2hwnd` is cleared when a box closes (lib/msgbox2.ahk:487), so `If MsgBox2hwnd Return`
  (:30616) cannot lock the panel.

## How this was checked

- Read at `7802a22` (`development`): the panel's code (:30606-32392) and every helper that a button,
  a menu item, a key or a drag reaches. Keys go `WM_KEYDOWN()` :701 → `PreProcessKbdKey()` :587 →
  `KeyboardResponder()` :735; the tree window, owned by the main window, counts as one of its
  children for `identifyParentWind()` (:27413). The tree's own events go to `FolderTreeResponder()`
  (:30826).
- Run under headless Wine, AutoHotkey_H 1.1.33.10 from the repository's zip, with two small scripts
  in `.claude/scratch/folders-tree-panel-2026-11-18/` (`run-ht.sh`, `run-mk.sh`; not committed):
  `hashTable` keys are case-sensitive (finding 11); `FileCreateDir` on an existing folder sets
  ErrorLevel 0 (finding 16).
- Not run: the application itself, and with it every key, menu item and drag. The folders list
  audit's kit (`.claude/scratch/static-folders-panel-2026-11-10/app/`) can drive the tree if these
  findings need runs.
