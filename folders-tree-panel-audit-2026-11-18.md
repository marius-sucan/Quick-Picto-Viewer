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

**Findings 1 to 3, 2026-11-18, fixed at `6d419b7`**, with Marius's answers: «No» to «Scan
recursively?» no longer scans, and the box can reopen the .SLD list or the database that was open
(`6d419b7`, decision 2 kept); the «`\\`» menu's folder items and Ctrl/Alt+Page Up/Down ask the three
questions of «Open folder now» first (`9daf923`); the «Open» submenu's hints follow the code (`dc69bd9`,
decision 1). The three were run in the application under headless Wine, before and after the fixes
(batches F1 to F3 of `.claude/scratch/folders-tree-fixes-2026-11-18/`). Decision 11, raised by the
fix of finding 1 and settled the same day: the «`\\`» menu's moves from a list pass the list when it
has its file (`548359a`, batch F4). Two effects of that on the sibling navigation, found by a check
of `548359a`, are fixed in `67d7343`: a sibling answered «No» keeps its name in «Sibling folders»,
and the navigation's tooltip comes only for a folder that was opened. «Seen in passing» E and F, the
position and the current folder of the sibling navigation, are fixed in `1cb0ba9`. Of the nine small
things of section 17, b, h and i are fixed in `ca8109b`, and f in `5624fa8`. «Seen in passing» G, the
list type after a database is imported from the welcome screen, is fixed in `bb730af`. The runs of
batches S and I (small thing f, «Seen in passing» G to I) were on AutoHotkey 1.1.37.02. The line
numbers below stay those of `7802a22`.

**Findings 5 to 12, 2026-11-18, fixed at `1313a18`**, with Marius's answers. Each was first run in
the application under headless Wine, on AutoHotkey 1.1.37.02, at `54c1996`, and each of the eight
did what the audit describes; the same batches were then run with the fixes. «Rename folder» looks
for the new name beside the folder (`e1ca39e`) and, with its tick, carries the opened folder, the
seed folders list and the folders list (`de9725d`, decision 3); a folder dropped on a missing folder
is copied or moved once that folder is recreated (`d57df45`); «Copy/Move selected file(s) into...»
takes a folder of any length and asks before it recreates a missing one (`292aadd`); files dropped
with Alt still held are copied or moved (`cc36dc1`); an import that brings no file in leaves the
current file where it was (`0fb1617`); a folder is listed once whatever the case of its label
(`5b0ac28`); and the confirmation of a drag between siblings names the dragged folder as the source
(`1313a18`). The omnibox's side of findings 5 and 7 to 10, which shares the corrected functions, was
run as well (batch T13). Decisions 12 to 15 were raised by these runs and settled the same day.

**Findings 4 and 13 to 16, 2026-11-19, fixed at `80b75e0`**, with Marius's answers. Each was first
run in the application under headless Wine, on AutoHotkey 1.1.37.02, at `b8b45c5`, and each of the
five did what the audit describes; the same batches were then run with the fixes. With no list
loaded, F3 and a drop on the main window open the folder in QPV, with its sub-folders when Shift is
held (`34e7c56`, decision 16); a folder moved by a drag leaves its old place in the tree
(`068c7fa`); Ctrl+X and Ctrl+C refuse a drive element (`f4bbf01`, decision 17); the «`\\`» menu's
notes count the folders not listed and sit in their own submenus (`43bee47`); «Create new folder»
checks the name the filter gives it, for a folder or a file (`80b75e0`, decision 18). Decisions 16
to 18 were settled the same day, before the fixes.

**«Seen in passing» M to P, 2026-11-19, fixed at `5c2853b`**, with Marius's answers. Each was first
run in the application under headless Wine, on AutoHotkey 1.1.37.02, at `35a7c94`, and each did what
its entry describes. With no list loaded, the omnibox's F3 and its drop on the main window open the
folder as the tree's do, with its sub-folders when Shift is held (`748004d`, decision 19); a folder
moved by any paste or drag leaves its place in the tree, the removal made where every move is made
(`181ed2b`, decision 20); a folder can be named `0`, and the omnibox finds such a folder again
(`4de0385`, decision 21); the scan tooltips show a folder without its sub-folders by its path, and
say so (`5c2853b`, decision 22).

**The open «small things» and «Seen in passing», checked 2026-11-19 at `15e9716`.** Small thing e is
fixed by Marius in `a4c35d0`; the effect it described could not be shown, and its entry says why.
The fourteen other open items hold as described: «Seen in passing» C, a comment, by reading, and the
thirteen others by runs in the application under headless Wine, on AutoHotkey 1.1.37.02 (batches WSa
to WPQ, T10, T14 and VNx, «How this was checked»). The runs changed two entries: the drag of «Seen
in passing» A moves the omnibox's selection to its last row, the omnibox's list taking one selected
row, rather than selecting every row; and B holds for an unsaved list as well. They found three new
leads, «Seen in passing» R, S and T.

**Small thing g, 2026-11-19, fixed at `4c6a16d`.** «Open folder now», by Enter or a double-click,
finds a folder removed from the disk gone before it asks about the edited image, the list or the
selection, as the «`\\`» menu's moves do: the tree leaves the three questions to
`tryOpenGivenFolder()`, which asks them once it has found the folder. Run in the application under
headless Wine, on AutoHotkey 1.1.37.02, at `8ee6fef` and with the fixed text (batches WSg and WGa).
The omnibox's «Open folder now» still asks before it finds the folder gone, a new lead, «Seen in
passing» U.

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

| # | Finding | Harm | Checked | Shared with | Status at `4c6a16d` |
|---|---------|------|---------|-------------|--------|
| 1 | «Scan recursively?»: the answer «No» is ignored; after a failed open a .SLD list or a database is not reopened | high | read | six other callers of `tryOpenGivenFolder()` | **fixed**, `6d419b7`: only «Yes» scans; a checkbox reopens a .SLD list or a database, from the «`\\`» menu too since `548359a` (decision 11); there a sibling answered «No» keeps its name since `67d7343` |
| 2 | The «`\\`» button's folder items replace an edited image, a modified .SLD list or a selection without the questions «Open folder now» asks | high | read | Shift+F4 menu | **fixed**, `9daf923`: the three questions, for the keys too |
| 3 | Shift and Ctrl with Enter or a double-click do the reverse of the menu's hints | medium | read | the folders list panels' open code | **fixed**, `dc69bd9`: the hints change (decision 1) |
| 4 | No list loaded: Shift+F3, or a drop on the main window with Shift held, opens a new QPV instance | medium | read, then run | — | **fixed**, `34e7c56`: the folder opens in QPV, with its sub-folders when Shift is held; Ctrl is not read (decision 16) |
| 5 | «Rename folder» looks for the new name inside the folder instead of beside it | medium | read, then run | omnibox F2 | **fixed**, `e1ca39e`: the name is looked for beside the folder, a file of that name included; a change of case alone passes, an unchanged name does nothing (decision 12) |
| 6 | «Rename folder» with «Perform search and replace»: the opened folder, the seed folders list and the folders list keep the old path | medium | read, then run | omnibox F2 | **fixed**, `de9725d`: the tick carries the three, in a database its tables too; it is offered only when a list is loaded (decision 3) |
| 7 | A folder dropped on a missing folder: the destination is recreated, then nothing is copied or moved | medium | read, then run | the omnibox's drags | **fixed**, `d57df45`: the folder is copied or moved into the recreated folder |
| 8 | «Copy/Move selected file(s) into...» and file drops: a destination of four characters or fewer opens the quick file actions panel | medium | read, then run | the omnibox's copy and move | **fixed**, `292aadd`: a folder of the tree or the omnibox is taken at any length; a missing one is asked about first (decision 13) |
| 9 | Files Alt+dragged from the main window: Alt still held half a second after the drop opens Explorer instead | low | read, then run | drops on the omnibox | **fixed**, `cc36dc1`: a drop does not read Alt; the menu items still do (decision 14) |
| 10 | «Import images into the list» moves the current file to the end of the list, also when nothing was imported | low | read, then run | the omnibox's F3 and its two import rows | **fixed**, `0fb1617`: the current file moves only when files came in or the folder was rescanned (decision 15) |
| 11 | A label whose case differs from the disk's: the tree lists the folder twice (every database list) | medium | run | — | **fixed**, `5b0ac28`: names are compared, and kept as keys, in lower case |
| 12 | A drag between two sibling elements: the confirmation box swaps source and destination | medium | read, then run | — | **fixed**, `1313a18`: the box names the dragged folder as the source |
| 13 | A folder moved by a drag stays in the tree at its old place | low | read, then run | — | **fixed**, `068c7fa`: the dragged element goes once its folder has moved; since `181ed2b` for every move («Seen in passing» N) |
| 14 | Ctrl+X and Ctrl+C put a whole drive on the clipboard | low | read, then run | — | **fixed**, `f4bbf01`: both keys refuse a drive element (decision 17) |
| 15 | The «`\\`» menu: the «more folders» notes land in the siblings submenu, and the count is one short | low | read, then run | Shift+F4 menu | **fixed**, `43bee47`: each note in its own submenu, counting the folders not listed; 200 sub-folders listed |
| 16 | «Create new folder»: a name the filter changes can land on an existing folder, listed twice | low | run | omnibox F7 | **fixed**, `80b75e0`: the name the filter gives is checked, for a folder or a file (decision 18) |
| 17 | Small things (nine points) | low | read, then run | | b, h, i **fixed**, `ca8109b`; f **fixed**, `5624fa8`; e **fixed**, `a4c35d0`; g **fixed**, `4c6a16d`; a, c, d open, each confirmed by a run at `15e9716` |

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

**Fixed in `6d419b7`**, by Marius's answers. Only «Yes» scans with the sub-folders. When the list open
before is a .SLD or .SLDB file that still exists, the box has the checkbox «Reopen the initial files
list if no images are found», ticked the first time and then as the user last left it until QPV
closes (a `Static` in `tryOpenGivenFolder()`). Ticked, «No» or a scan with the sub-folders that
finds nothing reopens that list with `OpenSLD()`, at the file shown before; unticked, the welcome
screen comes. With no list loaded, a previous folder that is gone, or a list with no file behind it
(the favourites, the histories), the box has no checkbox and «No» ends on the welcome screen. After
a reopen, `prevOpenFolderPath` keeps the list's folder, which `OpenSLD()` records, instead of the
list file. Decision 2: kept; with a plain folder open there is still no question. Decision 11, by
Marius's answer (`548359a`): with a .SLD list or a database open whose file exists, the items of the
«`\\`» menu's «Sibling folders», «Sub-folders» and «Breadcrumb folders hierarchy» pass the list
too, so the box comes there with its checkbox; with the favourites, a history list or a list whose
file was deleted they still pass the current file's folder, so there is no question, and a scan that
finds nothing opens that folder with its sub-folders. Ctrl/Alt+Page Up/Down and the menu's other
moves need a plain folder. Run, batch F1 (eleven cases, each box answered from a
timer): at `0013f5f` seven fail, «No» scanning in each of the six cases that answer it and no list
being reopened; with the text of `6d419b7` the eleven pass, the checkbox comes up as described, and
the reopened database answers a query.

**The sibling navigation after `548359a`, fixed in `67d7343`**, by Marius's answer.
`FileExploreSiblingsNav()` reads the return value 1 of `tryOpenGivenFolder()` as «no images there»:
it drops the sibling's name from its list and goes back to the position it had. With the list
passed, 1 also came back after «No» with the list reopened, so «Sibling folders» listed that folder
as a number without a name, and picking that item opened another sibling in place of the list. With
the checkbox unticked, «No» or a scan that found nothing ended on the welcome screen with 0, the
value of an opened folder, so the «Sibling folders navigation» tooltip replaced the «No image files
found» warning. Now `tryOpenGivenFolder()` returns «declined» when the box is answered with anything
but «Yes», closing it included, and 1 whenever a scan found nothing, the welcome screen included.
After «declined» the sibling navigation keeps the name and only goes back to its position; it drops
a name only after a scan that found nothing, and shows its tooltip only for a folder that was
opened. Run, batches R and D of `.claude/scratch/commit-548359a-check-2026-11-18/`: in nine calls of
`tryOpenGivenFolder()` the end state is the same before and after, and only «No», a closed box and
the welcome screen after a scan that found nothing return another value; of ten checks through the
«Sibling folders» items, seven fail at `68bf562` and the ten pass with the text of `67d7343`.

An unsaved list that carried the name of a saved list of its folder (`NewFilesList.SLD`,
`NewFile.SLD`) passed for that file in the test above, so the box had the checkbox and reopened the
saved list. Since `ae07174` an unsaved list takes a name that no file has, the first free
«name [N].SLD», and the box comes without the checkbox.

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

**Fixed in `9daf923`**, by Marius's answer: `tryOpenGivenFolder()` has a fourth parameter, `askFirst`.
With 1 it asks «Save image», «Save files list» and «Discard selection» once it found the folder and
before it closes the database or the list, and it returns «cancel» when one of them stops it.
`FileExploreSiblingsNav()`, `FileExploreUpDownLevel()` and `folderzNavInvokeSubs()` pass 1, so the
«`\\`» button, Shift+F4, the toolbar's folders button and Ctrl/Alt+Page Up/Down ask. The tree, the
omnibox and the folders list panels ask on their own and pass nothing: «Discard selection» has no
300 ms memo, and it would come twice. After «cancel» the sibling navigation forgets the position it
had moved to, so the next step starts from the folder still open. Run, batch F2: at `0013f5f` no
question comes on any of the seven moves; with the text of `6d419b7`, «Discard selection» and «Save
files list» come up for «Open next sibling», for the «Sub-folders», «Breadcrumb folders hierarchy»
and «Sibling folders» items and for «Breadcrumb higher level»; «No» and «Cancel» leave the list and
the selection as they were, the next «Open next sibling» opens the sibling after the open folder,
and `tryOpenGivenFolder()` called as the tree calls it still asks nothing.

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

**Fixed in `dc69bd9`**, by Marius's answer to decision 1: «In Explorer» shows Ctrl+Enter and «With a
new QPV instance» Shift+Enter, as the code reads the keys and as
`resources/help-keyboard-shortcuts.txt` (:255-256) has said since v5.2.0; the hints came with
v5.6.5. The keys are unchanged. Keys pressed in the tree reach only its hidden default button:
`identifyParentWind()` counts the tree as a child of the main window, and that branch of
`KeyboardResponder()` has nothing for Enter in the tree, so the main window's Shift+Enter (crop) and
Ctrl+Enter (new instance) never run from it. Run, batch F3: the menu as built reads «In Explorer
[Ctrl+Enter]» and «With a new QPV instance [Shift+Enter]» (at `0013f5f`: Shift+Enter and
Ctrl+Enter). Lead C is still not run.

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

**Confirmed by a run, then fixed in `34e7c56`**, with Marius's answer to decision 16. Run at
`b8b45c5`, batch U4. The tree was built while a folder was open and the list was then closed, so
that the tree was never built with no list loaded, a build that reads every drive; the kit gave the
Shift and Ctrl keys. With no list loaded, Shift+F3 and a drop with Shift held asked for a new QPV
instance and opened nothing in QPV; Ctrl+F3 and a drop with Ctrl held opened Explorer (logged by the
kit in place of being started); the tooltip over the main window said «Drop folder here to import it
into the current list.» all the same. `folderTreeAppendFiles()` now passes «open» or
«open-recursive» to `folderTreeDefaultAction()`, which then reads no key. With Shift held, or for a
drop made with Shift held, the folder opens with its sub-folders and without «scan recursively?»,
through the new last parameter of `tryOpenGivenFolder()`, `recursive`; a folder with no image
anywhere leaves the welcome screen as it was, with «No image files found in the folder». Without
Shift the folder opens as «Open folder now» opens it, «scan recursively?» included. With no list
loaded the tooltip reads «Drop folder here to open it.» above its Shift line. With a list loaded the
import is unchanged. On a drive element, Shift+F3 with no list now opens the whole drive with its
sub-folders, as the import does with a list (decision 5; read). The omnibox's F3 and its own drop on
the main window still open the folder without its sub-folders («Seen in passing» M). With the fix
the thirteen checks of batch U4 pass; at `b8b45c5` eight fail. Batch U4x calls
`folderTreeAppendFiles()` as a drop calls it, with Shift and Ctrl up: «recursive» now opens the
folder with its sub-folders, where at `b8b45c5` it opened it without them; «not» opens it without
them at both.

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

**Confirmed by a run, then fixed in `e1ca39e`**, with Marius's answer to decision 12. Run at
`54c1996`, batch T5: `2024` renamed to «old» while `2024\old` exists is refused with «A folder with
the given name already exists»; `2025` renamed to «taken», the name of a folder beside it, ends in
«ERROR: An unknown error occurred renaming the folder»; F2 in the tree and the omnibox's F2 (batch
T13) do the same. The run added two cases: a name left unchanged counted as a rename, and with the
tick it ran the search and replace; a file of the new name beside the folder gave the same unknown
error. `UIcoreFolderRename()` now looks beside the folder with `FileExist()`, so the warning also
comes for a file and says which of the two holds the name. A name that differs from the old one by
its case alone, in É as in A to Z, is not looked for, since the folder itself would be found. An
unchanged name closes the box and nothing else. The names are compared as text: `7` renamed to `07`
is a rename, refused when a folder `07` is beside it; `==` alone takes two such names, equal as
numbers, for one (run with a first text of the fix: the rename of `7` to `07` did nothing). With the
fix the ten checks of batch T5 pass; at `54c1996` six fail. Under Wine a rename that changes the
case alone leaves the name on the disk as it was, so the two checks on it show only that the rename
is no longer refused; what Windows does with it was not run.

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

**Confirmed by a run, then fixed in `de9725d`**, with Marius's answers to decision 3: the tick
carries all three, and it is offered only when a list is loaded. Run at `54c1996`, batch T6: after a
rename with the tick the files list holds the new path, while the opened folder of a plain list, the
seed folders list, the folders list and, in a database, the `staticfolders` table hold the old one;
F5 then lists `\Alpha` in bold beside `\Alpha9`; with no list loaded the box offers the tick.
`renameFolderInLists()` now runs the search and replace and, when it succeeded, three more steps. It
gives `CurrentSLD` the new path when that names the renamed folder or something inside it: the
opened folder of a plain list, which keeps its `|` when it was opened without its sub-folders, or
the file of a .SLD list saved in that folder. It rewrites the seed folders that are the folder or
are inside it (`renameDynamicFoldersEntries()`), in a database through
`recreateDynaFoldersSQLdbList()`. It renames the rows of the folders list with
`renameStaticFoldersEntries()` and, in a database, `renameStaticFolderSQLdb()`, which also moves the
captions and the audio notes. These are the steps of the seed folders panel's «Rename index entry»
(`PanelRenameStaticFolder()`). In a database the new path goes into the files list in lower case, as
the database holds its paths. Without the tick nothing follows the folder, as before. With the fix
the seventeen checks of batch T6 pass; at `54c1996` fourteen fail. Not carried, as after a rename
made in Explorer (read): the recent folders, the folder favourites, the six folders of the quick
file actions and the protected folder («Seen in passing» J).

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

**Confirmed by a run, then fixed in `d57df45`.** Run at `54c1996`, batch T7: a copy and a move onto
a folder that is gone, answered «Yes», recreate the folder and do nothing else, without a message;
so do a drag inside the tree and a drag from the omnibox onto the tree (batch T13).
`UIcoreFolderPasteFoldersInto()` now keeps the answer to «recreate?» apart from the action the drop
passed (since `292aadd` the question is asked by `askRecreateFolder()`), and the folder is copied or
moved into the recreated folder. With the fix the five checks of batch T7 pass; at `54c1996` three
fail. The copy and the move themselves were done by the kit: the Windows shell call that QPV makes
(`SHFileOperation`) asks, under Wine, a question that a run without a display cannot answer. The
runs therefore show which operation QPV asks for and on which two folders, not what Windows then
does.

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

**Confirmed by a run, then fixed in `292aadd`**, with Marius's answer to decision 13. Run at
`54c1996`, batch T8: with the element `C:\` → `\q` selected (the folder `C:\q`, four characters,
made for the run in Wine's own `C:` drive), «Copy selected file(s) into...» and «Move selected
file(s) into...» open the quick file actions panel, the tree closes, and no file is copied or moved;
the omnibox's «Copy selected file(s) into...» on that folder does the same (batch T13). The run also
showed that a destination of five characters or more that is not on the disk was created without a
word and the file copied into it. For a folder picked in the tree or in the omnibox,
`triggerQuickFileAction()` now tests that the folder exists instead of the length of its path. When
it does not exist, it asks what the folder paste asks, «Destination folder: … It seems to no longer
exist. Would you like to recreate it? By choosing yes, QPV will copy the selected file(s) into it»
(or «move»): «Yes» recreates the folder and goes on, any other answer stops. Both ask through
`askRecreateFolder()`. The six destinations of the quick file actions keep the length test and are
still created without a question. With the fix the seven checks of batch T8 pass; at `54c1996` six
fail. A drive element still receives no file: past the test, the copy and move code itself refuses
the root of a drive with «WARNING: Incorrect file path given: C:» (run); what a drive should accept
is part of decision 5.

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

**Confirmed by a run, then fixed in `cc36dc1`**, with Marius's answer to decision 14. The run
simulates the drag: the kit reports the button as held for three checks, the pointer as over the
tree, and the Alt key that `triggerQuickFileAction()` reads as held or released. Run at `54c1996`,
batch T9: a file Alt+dragged from the main window onto `\Gamma` is copied when Alt is released; with
Alt still down when the timer runs, Explorer is asked to open `\Gamma` and nothing is copied. A drop
on a row of the omnibox does the same (batch T13). `triggerQuickFileAction()` has a third parameter,
`fromDrop`: with 1 it does not read Alt, so neither the Explorer branch nor the new instance branch
runs. The two drops of `thumbsListClickResponder()` pass it through a bound function given to their
timer. The menu items «Copy/Move selected file(s) into...» keep the two tests: with Alt held, the
menu item still opens the folder in Explorer (run). With the fix the four checks of batch T9 pass;
at `54c1996` one fails.

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

**Confirmed by a run, then fixed in `0fb1617`**, with Marius's answer to decision 15. Run at
`54c1996`, batch T10: «Cancel» in the scan question moves the current file from 2 to 4 of 5, in a
plain list, a .SLD list and a database; «Cancel» in the box that says the folder is listed already
moves it too. The omnibox carries the same line: its two «import folder» rows after every outcome
(run, batch T13), and its F3 after Cancel in «Save image», where `addNewFolder2list()` returned no
value (read). `importFolderIntoList()`, which the tree, the omnibox's F3 and the two rows now call,
shows the next-to-last file when the list grew or ends in another file, or when the folder was
rescanned. After a cancel it leaves the file shown. When the folder brought no file in, a folder
without images, it shows the file shown before again: by then the import itself has picked a file at
random. `addNewFolder2list()` returns «cancel» after Cancel in «Save image» as well. As before, a
database shows a file picked at random after an import that brought files in. With the fix the
eleven checks of batch T10 pass; at `54c1996` six fail.

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

**Confirmed by a run, then fixed in `5b0ac28`.** Run at `54c1996`, batch T11, on a database of
`Photos\Summer`, `Photos\Winter` and `Photos\Été`: Space on the parent of `\photos` adds `\Photos`
beside it; F9 with another branch of the tree open adds `\Summer` beside `\summer`; F5 with the
current file in `été` lists `\Été` and a bold `\été`, and F9 then selects the parent in place of the
folder; a plain list opened as `photos\été` shows the same. `FolderTreeRepopulate()`,
`FolderTreeFindActiveFile()`, `iterateFDtreeView()` and `folderTreeScanSubbies()` now compare the
names in lower case, with `Format("{:L}")`, and give the `hashTable` its keys in lower case. They
also compare them as text: with a plain list on `nums\01` beside a folder `nums\1`, F5 marked both
as the current folder (run), two names that are equal as numbers being equal for `=`; it marks `\01`
alone now. The labels are as before: an element made from a path of the list keeps the list's case,
an element read from the disk the disk's. With the fix the eleven checks of batch T11 pass; at
`54c1996` seven fail. A plain or a .SLD list comes by such a path when a seed folder is scanned back
(«Seen in passing» L).

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

**Confirmed by a run, then fixed in `1313a18`.** The run simulates the drag as for finding 9. Run at
`54c1996`, batch T12: for `\Beta` dragged onto its sibling `\Gamma` the box reads «Source: .\Gamma\»
and «Destination: .\Beta\»; for two elements that are not siblings it shows both whole paths, the
source first; after «Yes», `\Beta` is copied into `\Gamma`. The two `TV_GetText()` calls now read
the dragged element into the source and the element under the drop into the destination. With the
fix the four checks of batch T12 pass; at `54c1996` one fails.

## 13. A folder moved by a drag stays in the tree at its old place

`FolderTreeResponder()` :31040-31046, `UIcoreFolderPasteFoldersInto()` :31899

After a move inside the tree, the selected element, the destination, is scanned again, twice:
inside `UIcoreFolderPasteFoldersInto()` (:31899) and at :31044-31045. The folder then shows under
its new parent, but its old element is never removed. The tree lists the folder in both places,
and every action on the old one says the folder no longer exists. After a move from the tree to
the omnibox, the rescan at :31899 runs on the dragged element, selected again while the pointer
was over the omnibox (:30949); its folder is gone, so it loses its children and stays. (read)

Correction: after a move, delete the dragged element.

**Confirmed by a run, then fixed in `068c7fa`.** The run simulates the drag as for finding 9, and
the kit does the shell's move (finding 7). Run at `b8b45c5`, batch U13: after `\m1` was moved onto
`\dst` with Shift, the tree listed `\m1` under `\dst` and still at its old place, with its child;
after `\m2` was moved onto an omnibox row, its old element stayed, without its child. Once a move by
a drag is done and the folder is no longer at its old path, `FolderTreeResponder()` now deletes the
dragged element, for both routes. A copy keeps it, and so does a move that failed (run: a folder of
that name was already in the destination, and the kit's move does not overwrite it). With the fix
the six checks of batch U13 pass; at `b8b45c5` two fail. A move made by «Paste folder(s) into...»
after «Cut folder», or by a drag of an omnibox row onto the tree, keeps the old element of a folder
the tree shows («Seen in passing» N). Since `181ed2b` the element is taken out by
`UIcoreFolderPasteFoldersInto()`, for every move and with the same test, and `FolderTreeResponder()`
no longer deletes it itself («Seen in passing» N); batch U13 passes with that text too.

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

**Confirmed by a run, then fixed in `f4bbf01`**, with Marius's answer to decision 17. Run at
`b8b45c5`, batch U14, the clipboard writes logged by the kit in place of being made: on the drive
element `Z:\`, Ctrl+X and Ctrl+C, through `folderTreeCutCopyFolder()` and through the key itself
with the tree active (`KeyboardResponder()`), asked for `Z:\` on the clipboard and said «CUT action:
the folder can now be pasted in any file manager or in QPV»; the menu on that element offers
neither. `folderTreeCutCopyFolder()` now asks `folderTreeIsDriveRoot()` first, as the rename and the
delete do, and the warning reads «An entire drive cannot be renamed, deleted, moved or copied», for
the three of them. F3, F7, F12, Enter and `;` on a drive are as before (decision 5). With the fix
the six checks of batch U14 pass; at `b8b45c5` three fail.

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

**Confirmed by a run, then fixed in `43bee47`.** Run at `b8b45c5`, batch U15, the menus as built and
read back, for a plain list on a folder with 200, 201 and 250 sibling folders and as many
sub-folders: with 201 siblings «Sibling folders» listed 200 and said «and 0 more folders», with 250
«and 49 more folders»; 201 sub-folders were listed with no note after them, and the note «... more
folders can be listed» was the last item of «Sibling folders»; with 200 of each there was no note,
as there should be. The siblings' and the parents' notes now count the folders not listed, the
parents' note goes into «Breadcrumb folders hierarchy», and the sub-folders' test comes before the
item is added, so that 200 are listed and the note follows them in «Sub-folders». The items keep
their numbers, which `folderzNavInvokeSubs()` reads back. With the fix the six checks of batch U15
pass; at `b8b45c5` four fail. More than 200 parents, and a folder with no sibling folders, were not
run.

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

**Confirmed by a run, then fixed in `80b75e0`**, with Marius's answer to decision 18. Run at
`b8b45c5`, batch U16: beside `photos`, «,photos» and «.photos» each added one more `\photos` element
and said nothing; «photos.» was refused, Wine finding the folder as the audit expected Windows to,
but the warning named `photos.\`; for «notes», the name of a file beside, the message was «ERROR: An
unknown error occurred creating the new folder»; the omnibox's F7 with «,Sub» beside `Sub` said
nothing. `UIcoreFolderNew()` now filters the name first and looks for it with `FileExist()`, as
«Rename folder» does: «A folder with the given name already exists» or «A file with the given name
already exists», with the name as it would be created. The filter is unchanged: «.config» still
becomes «config» without a word. With the fix the nine checks of batch U16 pass; at `b8b45c5` five
fail. A folder cannot be named `0` («Seen in passing» O). Names that the filter empties now get
«WARNING: Incorrect folder name given.»: at `b8b45c5` a blank name, «.» and «..» were refused with
«A folder with the given name already exists», the check finding the folder itself or its parent; no
folder was made at either (batch U16x).

## 17. Small things

b, h and i are fixed in `ca8109b`, f in `5624fa8`, e in `a4c35d0` and g in `4c6a16d`; a, c and d are as
described, at `15e9716` too, each confirmed by a run (2026-11-19, batches WSa, WSc and WSd). ✅ marks a
fixed one.

a. **Rename does not sort.** `TV_Modify(c, "Select Vis Sort", "\" newFileName)` (:31967) sorts the
   children of the renamed element (that is AutoHotkey's `Sort` option), not the element among its
   siblings: it keeps its old place. Still so at `15e9716`. Run, batch WSa: once «Rename folder» gave
   `\Alpha` the name `Zeta`, the children of `\pv` read `\Zeta`, `\Beta`, `\Gamma`, `\Holiday One`;
   F5 then lists `\Zeta` last.

b. ✅ **«Paste clipboard file(s) into...» brings the tree back only after Cancel.**
   `PasteFilesIntoGivenFolder()` returns 1 for Cancel (:32228) and nothing after a paste (it ends
   with `msgBeepTimer()` at :32391), and `folderTreePasteClippy()` activates the tree when the result
   is true (:32201-32203). **Fixed in `ca8109b`**: the tree is activated after every outcome.

c. **«Scan for sub-folders» can stay on a missing folder.** The item is removed by its label,
   ``&Scan for sub-folders`tSpace`` (:31636). `kMenu()` drops the key from a label when the user's
   own shortcuts give that key to another function (:71547-71561), and the removal then misses.
   Still so at `15e9716`. Run, batch WSc, with a custom keys file that the kit writes for the image
   view's key context: with Space given to «Next image», and again with the default Space shortcut
   disabled, the menu on a folder removed from the disk still offers «Scan for sub-folders», without
   its key; with no custom key the item is not there. The same rewrite takes the key off the item
   on the other elements too («Seen in passing» R).

d. **The «7» and «Shift+7» hints** of «Copy/Move selected file(s) into...» (:31628-31629): in the
   tree, 7 goes to the tree's own type-ahead search; in the main window, 7 runs the copy only with
   the quick file actions option on (`allowUserQuickFileActions`, off by default; :2052-2060,
   :47222). Still so at `15e9716`. Run, batch WSd: the main window's 7 and Shift+7 go to
   `triggerQuickFileAction()`, which copies nothing while the quick file actions are off and copies
   the current file into the selected element once they are on; the 7 key posted to the tree, the
   tree being the active window, reaches no quick file action, the quick file actions on.

e. ✅ **Alt+D opens the selected folder.** The hidden default button is labelled «&Default» (:30673),
   so its mnemonic runs «Open folder now». **Fixed in `a4c35d0`** (Marius): the button is labelled
   «Default», with no `&`. The effect was not seen, though. Run, batch WSe, at `a6b57e0` (the text
   before the fix) and at `15e9716`: Alt+D posted to the tree, as WM_SYSCHAR and as WM_SYSKEYDOWN,
   ran «Open folder now» at neither. The button is 0 pixels wide, its option `-wantTab` setting the
   width to 0 after `w1` («Seen in passing» T), and a BM_CLICK to it ran nothing in the application
   either. A copy of the panel's layout in a bare AutoHotkey window shows that the two go together:
   with `-wantTab` the button is 0×1 and neither Alt+D nor BM_CLICK runs it; without, it is 1×1 and
   both do. Enter does not depend on the button's size: Enter sent to the tree opened the folder
   (run). Not run on Windows.

f. ✅ **«Show folder details» on a folder with no images and no sub-folders** shows its parent's path
   instead of its counts: the counts are shown only when one is not zero (`If (dirs || sizu)`
   :31127). `ca8109b` added a flag to that test, `deadFolder`, set when the folder is not on the
   disk, the other case: the folder with nothing to count kept its parent's path, a folder removed
   from the disk showed «`\Gone | 0 KB |  images |  folders`», and with no element selected the
   line read «` | 0.0% free | 0 KB |  images |  folders`» in place of the count of the tree's
   elements («Folder tree: 20 elements» in the run); the counts are blank where nothing was counted.
   **Fixed in `5624fa8`**: the flag is set where the folder is on the disk and was counted. Run,
   batch S, at `cd42beb`, at `a560074` and with the fixed text: the folder with nothing to count
   shows «`\Empty | 0 KB | 0 images | 0 folders`», the removed folder its parent's path and no
   selection the count of elements, both as at `cd42beb`; a drive and the folders with images or
   sub-folders show their counts at all three.

g. ✅ **«Open folder now» on a missing folder** asks about the edited image, the list and the
   selection (:30767-30774), and only then finds the folder gone (`tryOpenGivenFolder()`
   :73297-73302). Still so at `15e9716`. Run, batch WSg: with a .SLD list of 212 files, modified, 30
   of them selected, Enter on the element of a folder removed from the disk asked «Save files list»
   and «Discard selection», then said «ERROR: Folder not found or access denied»; answered «Discard»
   and «Yes», the list stayed as it was. The menu offers no «Open» on such an element, so Enter and
   a double-click are the ways there. The «`\\`» menu's moves, which ask once `tryOpenGivenFolder()`
   has found the folder (finding 2), ask nothing for the same folder.
   **Fixed in `4c6a16d`**: `folderTreeDefaultAction()` no longer asks the three questions itself; it
   calls `tryOpenGivenFolder()` with its argument `askFirst` set to 1, as the «`\\`» menu's moves do,
   and stops when that returns "cancel". Run, batch WSg, at `8ee6fef` and with the fixed text: Enter
   on the missing folder now says «ERROR: Folder not found or access denied» with no question, the
   list as it was. Batch WGa, at both texts, Enter on an existing folder with the same list: the
   questions come in the same order, «Cancel» to the first and «No» to the second keep the list,
   «Discard» and «Yes» open the folder, and the tree is the active window after it. The «Save image»
   question, the first of the three, was not run: it moved with the other two (read).

h. ✅ **The rebuild test** `thisSize := 300 + PrefsLargeFonts + uiUseDarkMode` (:30625) gives 301 for
   large fonts in light mode and for normal fonts in dark mode: if both settings change while the
   tree is hidden, it comes back with the old look. A change of the large font size
   (`LargeUIfontValue`) is not in the test either. **Fixed in `ca8109b`**: the test compares the
   three settings, each on its own.

i. ✅ **«Paste folder(s) into...» with no folder found** shows the whole clipboard text in its warning
   (:31904). **Fixed in `ca8109b`**: the warning names the action alone. It ends with `pku`, a
   variable that nothing sets in that function, so nothing shows of it.

## Decisions to make before fixing

1. **Shift and Ctrl** (finding 3): keep the code (Shift = new instance, Ctrl = Explorer, as the
   folders list panels do) and change the hints, or keep the hints (Ctrl+Enter = new instance, as in
   the main window's menus) and swap the code?
   **Settled**: the hints change (`dc69bd9`).
2. **The scan with sub-folders without a question** (finding 1): when a plain folder was open and
   the new folder holds no image directly, `tryOpenGivenFolder()` scans it with its sub-folders
   without asking. Keep, or ask every time? Six other callers share it.
   **Settled**: kept (`6d419b7`).
3. **What the rename's tick carries** (finding 6): the opened folder (`CurrentSLD`), the seed folders
   list, the folders list (in a database its tables, with the captions and audio notes), or a part of
   these? And should the tick be offered when no list is loaded?
   **Settled**: all of them, and the tick is offered only when a list is loaded (`de9725d`).
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
11. **The «`\\`» menu's moves from a list** (finding 1, raised by its fix in `6d419b7`): with a
    .SLD list or a database open, the «Sibling folders», «Sub-folders» and «Breadcrumb folders
    hierarchy» items give `tryOpenGivenFolder()` the current file's folder as the previous one
    (`FileExploreSiblingsNav()`, `FileExploreUpDownLevel()`, `folderzNavInvokeSubs()`). Pass the
    list instead, so that they ask «Scan recursively?» with the checkbox and can reopen the list, or
    leave them?
    **Settled**: pass the list when its file exists (`548359a`); the favourites, the histories and a
    deleted list file keep the current file's folder. The sibling navigation tells «No» from a scan
    that found nothing since `67d7343` (finding 1).
12. **«Rename folder»: a name left unchanged, and a file of the new name** (finding 5, raised by its
    run): the first counted as a rename and ran the search and replace, the second gave «unknown
    error». Handle the two, or keep to the check beside the folder?
    **Settled**: both are handled (`e1ca39e`).
13. **A destination that is not on the disk** (finding 8, raised by its run): a drop of files on an
    element whose folder is gone created a folder of five characters or more without a word. Warn
    and stop, create it as before, or ask?
    **Settled**: ask «recreate?», as the folder paste does (`292aadd`).
14. **Who ignores Alt after a drop of files** (finding 9): the drops alone, or the menu items
    «Copy/Move selected file(s) into...» as well?
    **Settled**: the drops alone (`cc36dc1`).
15. **The current file after an import** (finding 10): leave it when nothing came in and show the
    next-to-last file after an import, as now, or show the first file that came in? In the tree
    alone, or in the omnibox too, which has the same line?
    **Settled**: it stays when nothing came in, in the tree and in the omnibox; after an import the
    next-to-last file is shown, as before (`0fb1617`).
16. **With no list loaded, what F3 and a drop on the main window do** (finding 4): open the folder
    with the keys not read, as the omnibox's F3 does; open it with its sub-folders when Shift is
    held; or import it into a new unsaved list?
    **Settled**: open it; Shift opens it with its sub-folders, without «scan recursively?»; Ctrl is
    not read (`34e7c56`).
17. **Ctrl+X and Ctrl+C on a drive element** (finding 14): refuse both, or Ctrl+X alone?
    **Settled**: both are refused, and the drives warning names copying too (`f4bbf01`).
18. **A name already taken in «Create new folder»** (finding 16): once the name is filtered, report
    a file of that name too, as the rename does, or folders only?
    **Settled**: a folder or a file, as the rename does; the filter stays as it is (`80b75e0`).
19. **The omnibox with no list loaded** («Seen in passing» M): open as the tree does since
    `34e7c56`, for the drop and F3; for the drop only; or change the tooltip alone?
    **Settled**: as the tree, for the drop and F3; after a drop with no list loaded, the tree's and
    the omnibox's tooltip says «Opening folder - please wait» (`748004d`).
20. **Where the element of a moved folder goes** («Seen in passing» N): in
    `UIcoreFolderPasteFoldersInto()`, for every move, in place of finding 13's deletion; only in the
    routes that lack it; or there, with the destination's element scanned again as well?
    **Settled**: in `UIcoreFolderPasteFoldersInto()`, for every move; finding 13's deletion in
    `FolderTreeResponder()` is gone (`181ed2b`).
21. **How far the names read as false go** («Seen in passing» O): the create and the rename only, or
    the omnibox's selection of the renamed folder too?
    **Settled**: both; the omnibox compares the names as text (`4de0385`).
22. **What the scan tooltips show for a folder without its sub-folders** («Seen in passing» P): the
    path alone, or the path and the mode?
    **Settled**: the path, with «(without its sub-folders)» under it (`5c2853b`).

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
  default button was not run, and still is not: the fix of finding 3 changes only the hints.

## Seen in passing

Outside the panel's own code, found while tracing its actions. ✅ marks a fixed one.

- **A. The main window's Alt+drag over the tree moves the omnibox's selection to its last row.** In
  the thumbnails click handler (:9611), the drag's tree branch calls `LV_Modify(initialRow,
  "select")` (:9757). `initialRow` exists only in the omnibox's handler (:42517); here it is blank,
  which counts as row 0, every row. With the omnibox open in folder mode, the default window there
  is the omnibox's (:9714-9716), so hovering the tree selects the rows of its list in turn; the list
  keeps one selected row (`-multi`), the last, and the omnibox's folder actions then work on that
  row. The tooltip says «Move or copy folder into another one» while files are dragged (:9758).
  Still so at `15e9716`. Run, batch WPA: with the omnibox open on `pv` and its row `\Gamma`
  selected, an Alt+drag of a file over the tree's `\Beta`, answered «No», left the row `\Holiday
  One` selected (`OmniBoxGetSelectedFolder()` gave `pv\Holiday One`), and the drag's tooltip read
  «Move or copy folder into another one. Hold SHIFT to MOVE.».
- **B. A plain list grown by imports is replaced without a question.** `askAboutSlidesListSave()`
  (:65471) asks only for a .SLD list and the favourites; a plain list that the tree's F3 grew is
  replaced by any open (finding 1's callers) without a word. Still so at `15e9716`, and for an
  unsaved list too: the function asks only when the list's name is a file on the disk, and an
  unsaved list has no file yet. Run, batch WPB: a plain folder of five files grown to seven by F3,
  and an unsaved list of three files added on the welcome screen, were each replaced by «Open
  folder now» with no question; a modified .SLD list got the question, and «Cancel» kept it.
- **C. The comment `; F3` on `c=186`** (:30858): the key is `;` (VK_OEM_1), which opens the omnibox
  at the element. Still so at `15e9716` (read).
- **D. «Selected file folder» asks two of the three questions.** `OpenQPVfileFolder()` (:2819), the
  «`\\`» menu's item for the current file's folder with a .SLD list or a database, also Alt+E in the
  thumbnails view, asks «Save image» and «Save files list» but not «Discard selection» before it
  replaces the list (read; found while fixing finding 2). Still so at `15e9716`. Run, batch WPD: with
  a .SLD list of 212 files, 30 of them selected, «Open folder now» asked about the selection and
  «No» kept the list; «Selected file folder» (`OpenQPVfileFolder()`) asked nothing and opened the
  current file's folder in place of the list, the selection gone.
- ✅ **E. The sibling navigation after a sibling with no images.** When `tryOpenGivenFolder()` reports
  a failure, `FileExploreSiblingsNav()` sets its position back to `initialLevel` (:65175-65176), the
  value it held when the call began. That value is blank on the first move after QPV starts and
  after the tree, the omnibox or a folders list panel opened a folder; the next step then computes a
  blank level (`"" + 1` is blank), and `clampInRange()` with wrap-around turns blank into the last
  sibling. So the next Alt+Page Down after a sibling with no images jumps to the last sibling (read;
  found while fixing finding 2). **Fixed in `1cb0ba9`**: the position a move starts from is taken
  after the current folder is looked up (F), so it is never blank. Run, batch G: at `3e7ad12` the
  step after a failed first move opens the last sibling; with the fix it opens the next one, and
  the sibling with no images is skipped in both directions.
- ✅ **F. The sibling navigation keeps a stale current folder.** `FileExploreSiblingsNav()` looked for
  the current folder among its siblings only when their parent folder changed. With a .SLD list or a
  database open, a move to a file in another folder under the same parent left the check mark of
  «Sibling folders» on the folder left behind, and picking that folder did nothing. With a plain
  folder opened by a route that does not reset the navigation (the tree, the omnibox and the folders
  list panels reset it), next and previous stepped from the folder left behind. A database also
  missed a folder named with an accented capital: its paths are in lower case, and `=` folds only A
  to Z. Found by the check of `548359a`. **Fixed in `1cb0ba9`**: at every call from outside, the name
  is looked up among the siblings remembered, with no disk read, and compared with `Format("{:L}")`;
  when it is not among them, a folder made since, the parent folder is read again, once, and a
  folder still not found counts as no current sibling. The folder with the check mark stays inert
  when picked, as the open folder is. Run, batch G: at `3e7ad12` eleven of twelve checks fail, with
  the fix the twelve pass. Not run: a drive root, whose branch is unchanged.
- ✅ **G. A database imported from the welcome screen left the list without its type.** Insert, or
  «Insert file(s)» in the «File» menu, with a database picked while no list is loaded, runs
  `importSLDBintoPlainText()`: the files of the database become an unsaved list, named
  `newFile.SLD` in the folder of the database. The function named the list and left the list type
  (`SLDtypeLoaded`) at 0, its value on the welcome screen; the five other places that name an
  unsaved list set 2, the type of a .SLD list. With 0, «Save files list now» was missing from the
  «Files list» menu and from the context menu, the image information box had no «Files list opened»
  line, and the save panel said «No saved files list currently opened». Found while fixing the
  names of the unsaved lists (`ae07174`). **Fixed in `bb730af`**: the function sets 2 where it names
  the list. Run, batch I: at `ca8109b` four of nine checks fail, with the fix the nine pass. The
  list now behaves as the other unsaved lists do, also where they are refused: in the folders list
  panel, the rename of a folder entry answers «The loaded .SLD file does not seem to be in the
  correct format» until the list is saved; before, the rename box came. The same import with a
  saved .SLD list or a folder open keeps the name and the type of what was open, and a file that is
  not a database, or a database without images, loads nothing: as before, run.
- **H. A .SLD list picked with Insert is imported only into a .SLD list or an unsaved list.**
  `importSLDplainText()` returns at once, with no message, unless the name of what is open ends in
  `.sld`: on the welcome screen (run), and by the same test with a folder or a database open
  (read). A database picked the same way is imported. Found while fixing G. Still so at `15e9716`,
  now run in the three cases. Run, batch WPH: a .SLD list of two files picked with Insert brought
  nothing in, with no message, on the welcome screen, with a plain folder open and with a database
  open; with a .SLD list open its two files came in, and a database picked with a folder open came
  in too.
- **I. «Save settings into current .SLD file» and «Load settings from current .SLD file» always
  refuse.** `WritePrefsIntoSLD()` and `LoadPrefsFromSLD()` begin with the test under which the
  «Preferences» menu offers the two items, a .SLD list or a database of more than one file, and
  return «ERROR: No valid files list currently opened» when that test holds, since `1c3b9c3`
  (v6.1.75). Run, `WritePrefsIntoSLD()` with a saved list of two files open: the error comes and
  the file is unchanged. Found while fixing G, after which the two items are offered for one more
  list. Still so at `15e9716`. Run, batch WPI: with a .SLD list of five files open, the context menu
  offers both items; «Save settings into current .SLD file» answered «ERROR: No valid files list
  currently opened» and left the list's `hueAdjust` at 0 (123 in memory), and «Load settings from
  current .SLD file» answered the same and left 50 in memory (0 in the list); with a database of
  five files open, both answered it too.
- **J. The protected folder keeps the old path after «Rename folder».** The deletions compare the
  path of each file with `protectedFolderPath` (`batchFileDelete()`, `InListMultiEntriesRemover()`).
  Once the tree or the omnibox has renamed the protected folder, or a folder that holds it, the
  setting names a folder that is gone: its files are no longer skipped, and the check mark of «Set
  as the protected folder» is gone too (read; found while fixing finding 6, whose tick carries the
  lists and not this setting). Still so at `15e9716`. Run, batch WPJ, through the tree's «Rename
  folder» with the tick: before the rename, a file of the protected folder `pv\Beta` selected for
  deletion is skipped («Skipped files: 1»); once `\Beta` is renamed `Beta2`, the list follows, the
  setting still names `pv\Beta`, the menu no longer checks «Set as the protected folder» on
  `\Beta2`, and the same file is deleted («1 out of 1 selected files deleted»). The omnibox's
  rename was not run.
- **K. «Use Alt to open it in Explorer», in the quick file actions panel, is not reached from the
  keys.** The keys 1 to 7 and Shift+1 to Shift+7 are sent to `triggerQuickFileAction()`; Alt+1,
  Alt+6, Alt+7 and Ctrl+Alt+1 are sent to no function (run, batch T14, through
  `processDefaultKbdCombos()` in the mode that only names the function of a key). The function's Alt
  test, and its Ctrl+Alt test for a new QPV instance, therefore run only when Alt is held while a
  menu item calls it. Found while fixing finding 9. Still so at `15e9716`: batch T14 again gives the
  same routing.
- **L. A seed folder scanned back lists its files under a folder path in lower case.** The seed
  folders list is kept in lower case (`cleanDynamicFoldersList()`), a rescan scans the entry as the
  list holds it (`coreRescanDynaFolder()`), and `Loop, Files` returns each file under the folder
  path it was given. Run, batch T10: after «Rescan» in a plain list, the four files of `Holiday One`
  are listed as `holiday one\h1.png` and so on. Such paths are what finding 11 met in plain and .SLD
  lists. Found while fixing finding 10. Still so at `15e9716`: batch T10 again lists them so after
  «Rescan».
- ✅ **M. The omnibox's drop on the main window, with no list loaded.** A row of the omnibox dragged
  onto the main window imports the folder (`LVquickSearchMenusResponder()` →
  `omniBoxFolderImport()`); with no list loaded that opens it with `omniBoxFolderOpen()`, as «Open
  folder now» does, whatever Shift says, while the tooltip reads «Drop folder here to import it into
  the current list.» and «Hold SHIFT for recursive scanning.» (read). The tree's twin is finding 4,
  where Marius chose that Shift opens the sub-folders; the omnibox was left as it is. Found while
  fixing finding 4. **Fixed in `748004d`**, with Marius's answer to decision 19. Run, batch VM, at
  `35a7c94`: with no list loaded, an omnibox row dropped on the main window with Shift held opened
  `\Alpha` without its sub-folders (three files of five) under «Drop folder here to import it into
  the current list.» and «Folder is to be RECURSIVELY scanned.»; the omnibox's Shift+F3 on a folder
  with images only in a sub-folder asked «scan recursively?». `omniBoxFolderImport()` now hands
  «recursive» to `omniBoxFolderOpen()` when Shift is held, or the drop was made with Shift held, and
  `omniBoxFolderOpen()` passes it on to `tryOpenGivenFolder()`; it takes a mode only together with
  «yes», as the omnibox's other functions do, since its menu item calls it with the item's name.
  With no list loaded the drop's tooltip reads «Drop folder here to open it.», and after a drop from
  the omnibox or from the tree «Opening folder - please wait». With the fix the eight checks of
  batch VM pass; at `35a7c94` four fail.
- ✅ **N. A folder moved by «Paste folder(s) into...», or by a drag of an omnibox row, stays in the
  tree.** After «Cut folder» and «Paste folder(s) into...» with «Move», or after a drag of an
  omnibox row onto the tree with Shift, `UIcoreFolderPasteFoldersInto()` scans the destination
  element again, and an element of the moved folder, when the tree shows one, stays at its old place
  (read). Finding 13's fix covers the drags that start in the tree. Found while fixing finding 13.
  **Fixed in `181ed2b`**, with Marius's answer to decision 20. Run, batch VN, at `35a7c94`, the
  clipboard's text given by the kit: after the tree's «Paste folder(s) into...» with «Move», the
  omnibox's, an omnibox row dragged onto the tree and one dragged onto another row, each with Shift,
  the tree listed the moved folder under `\dst` and still at its old place.
  `UIcoreFolderPasteFoldersInto()` now notes every folder it moves and, after its scan of the tree,
  takes out the element of each that is no longer on the disk, found by its path with
  `iterateFDtreeView()`, the walk F9 uses; a copy keeps it. The deletion that finding 13's fix put
  in `FolderTreeResponder()` is gone. With the fix the nine checks of batch VN pass; at `35a7c94`
  four fail. With the folders tree never opened, an omnibox row moved onto another row is moved as
  before (batch VNx). The destination's element is another matter («Seen in passing» Q).
- ✅ **O. A folder named `0` can be neither created nor given by «Rename folder».** `UIcoreFolderNew()`
  and `UIcoreFolderRename()` test the name with `If !newFileName`, and AutoHotkey takes `0` for
  false: «Create new folder» answers «WARNING: Incorrect folder name given.», and «Rename folder»
  closes and does nothing (run, batch U16). Found while fixing finding 16. **Fixed in `4de0385`**,
  with Marius's answer to decision 21. Run, batch VO, at `35a7c94`: «0» and «00» were refused, and
  «000» given to «Rename folder» in the tree and «0000» in the omnibox did nothing; with folders `0`
  and `0000` side by side, the omnibox listed again to select `0000` or `0` selected its first row,
  and with that test alone corrected it selected `\0` for `0000` (run on a trial text). The two
  folder functions test for a blank name; the omnibox's selection tests the same way and compares
  the names behind a `\`, as text. With the fix the seven checks of batch VO pass; at `35a7c94` six
  fail. A rename to «0» with «Perform search and replace in current list» ticked carries the files
  list to the new path (batch VOx).
- ✅ **P. The import's tooltip shows the `|` of a folder scanned without its sub-folders.**
  `wrapperAddNewFolderToList()` shows «Preparing files list to import:» with the entry as it is
  given, so a folder imported without its sub-folders reads `|D:\…\` there (run, batch U4: a folder
  dropped on the main window with a list loaded). Found while fixing finding 4. **Fixed in
  `5c2853b`**, with Marius's answer to decision 22. The same `|` showed in «Loading files from»
  (`GetFilesList()` and its fallback `oldGetFilesList()`), which every plain folder open shows too
  (run, batch VP; the fallback by batch VPx, the kit making `GetFilesList()` hand over to it). The
  three tooltips show the path without it, and «(without its sub-folders)» under it. With the fix
  the three checks of batch VP and the one of batch VPx pass; at `35a7c94` three of the four fail.
- **Q. After the omnibox's paste or drags, the destination's element in the tree is not scanned
  again.** `UIcoreFolderPasteFoldersInto()` scans the tree's selected element after a copy or a
  move, which for the tree's own paste and drags is the destination. After the omnibox's paste or
  its drags, a destination that the tree shows without having it selected keeps its old children
  until Space or F5 (read). With the tree never opened, the same scan leaves an empty tree window
  behind, hidden (run, batch VNx, at `35a7c94` and with the last text). Found while fixing N.
  Still so at `15e9716`. Run, batch WPQ: with the tree's `\zz` selected and `\dst` showing its
  sub-folder `\old`, the omnibox's paste of `\m1` into its row `\dst` and a drag of its row `\m2`
  onto that row, both copies, left the tree's `\dst` with `\old` alone; Space on `\dst` then
  listed `\m1` and `\m2`. Batch VNx again: the hidden tree window is still left behind.
- **R. A custom key of the main window takes the key off an item of the tree's menu, while the
  tree keeps the key.** `kMenu()` drops the key from a label when the user's custom keys give that
  key, in the current key context, to another function or disable it (small thing c); the tree's
  menu is built the same way, but the tree reads its keys itself (`FolderTreeResponder()`),
  whatever the custom keys say. Run, batch WSc: with Space given to «Next image», «Scan for
  sub-folders» shows no key on `\Beta`, and Space in the tree still scans `\Beta`. The other keys
  of the menu go through the same code (read). Found while checking small thing c.
- **S. Four drag confirmations put a dot before a full path.** The boxes of a drag from the main
  window onto the tree, from the tree onto the omnibox, from the omnibox onto the tree, and inside
  the tree between elements that are not siblings write «Source: .» and «Destination: .» before the
  folder's full path (`thumbsListClickResponder()`, `FolderTreeResponder()` twice,
  `LVquickSearchMenusResponder()`), so a folder reads, for example, «.C:\Photos\Beta\». Between
  siblings, inside the omnibox and from the main window onto the omnibox the boxes give a name,
  «.\Beta\», as meant. Run: the logs of batches T9, T12, T13, U13 and WPA show the dot before each
  such path (the kits shorten a path to its part under their work folder). Found while checking A.
- **T. The hidden default button is 0 pixels wide.** `PanelFoldersTree()` adds it with `w1 h1
  -wantTab -TabStop Default`, and `-wantTab`, an option of edit fields, sets its width to 0 after
  `w1`: in the application the button is 0×1 pixels. Clicked by BM_CLICK or ControlClick, it runs
  nothing; it ran nothing on Alt+D either while its label had the `&` (small thing e). Enter still
  opens the folder, so nothing visible depends on it now. Run: batch WSe and the debug batches
  WSex, WSex2 and WSex3 in the application; a bare AutoHotkey window with the panel's layout gives
  the button 0×1 with `-wantTab` and 1×1 without, and only the 1×1 one answers Alt+D and BM_CLICK
  (`mnemonic/layout.ahk` of the kit). Found while checking small thing e.
- **U. The omnibox's «Open folder now» asks before it finds a missing folder gone.**
  `omniBoxFolderOpen()` (:27118) asks the three questions of «Open folder now», then calls
  `tryOpenGivenFolder()`, which finds the folder gone: small thing g, before its fix, in the
  omnibox. A row listed before its folder was removed from the disk stays in the omnibox's list,
  and Insert (:42494), Ctrl+Enter or Shift+Enter (:42719) and «Open folder now» of its menu
  (:27297) open it. Run, batch WGu, at `8ee6fef` and with the text of g's fix: with the .SLD list of
  212 files, modified, 30 of them selected, and the omnibox's row `\GoneU` selected, its folder then
  removed from the disk, `omniBoxFolderOpen()` asked «Save files list» and «Discard selection»,
  answered «Discard» and «Yes», then said «ERROR: Folder not found or access denied»; the list
  stayed as it was. Found while fixing g.

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
- The fixes of findings 1 to 3 were run in the application itself under headless Wine, at `0013f5f`
  and with the fixed text, by `.claude/scratch/folders-tree-fixes-2026-11-18/` (that kit with new
  test wrappers, `tree-tests.ahk`; `run-all.sh`; the logs in `app/results/`): `tryOpenGivenFolder()`
  called as the tree calls it once its own questions are answered, the navigation through its menu
  functions, the tree's menu as built, every box answered from a timer. AutoHotkey_H 1.1.33.10 and
  AutoHotkey 1.1.37.02 load the fixed text, with and without `/iLib`.
- Decision 11 (`548359a`) was run the same way, batch F4, at `e30c3e7` and with the new text: with a .SLD
  list, the «Breadcrumb folders hierarchy», «Sub-folders» and «Sibling folders» items to folders
  without images directly in them; with a database, a sibling; then a favourites-like list and a
  plain folder, which behave as before. At `e30c3e7` the four list cases fail, with no box; with the
  new text the six pass, and batches F1 and F2 pass again.
- The sibling navigation's fix (`67d7343`) was run the same way, at `68bf562` and with the fixed
  text, by `.claude/scratch/commit-548359a-check-2026-11-18/` (`fix-tests.ahk`, `run-fix.sh`; the
  logs in `app/results/`): batch R calls `tryOpenGivenFolder()` as the tree does and logs what it
  returns; batch D goes through the «Sibling folders» items, with the box answered «Yes», «No» or
  closed, and the checkbox ticked or not. Batches F1, F2 and F4 pass with the fixed text, F1 once
  its two cases that answer «No» with a list open expect «declined» in place of 1. AutoHotkey_H
  1.1.33.10 and AutoHotkey 1.1.37.02 load the fixed text, with and without `/iLib`.
- The current sibling (`1cb0ba9`) and the unsaved lists (`ae07174`) were run the same way, at
  `3e7ad12` and with the fixed texts, by the same kit (`fix2-tests.ahk`). Batch G: a list whose
  current file changes folder, a folder opened by another route (`OpenFolders()`, as the folder
  favourites and the omnibox open one), a first move that fails, a folder made since, a folder gone
  from the disk, a database with a folder named «Été». Batch H names an
  unsaved list through `coreAddNewFiles()`, `addNewFolder2list()`, `addSeedFoldersEntries()` and
  `importSLDBintoPlainText()`, with and without a saved list of that name in the folder, then saves
  it, opens a folder over it and offers it to the folder favourites; the rescan branch of
  `addNewFolder2list()` and the drop of several folders name the list the same way and were read.
  With the text of `1cb0ba9`, batches G, D and F4 pass; with the text of `ae07174`, batches G, H, D,
  E, F1, F2 and F4 pass, and batch R, which only logs, returns the nine values it returned at
  `67d7343`. Both interpreters load both texts, with and without `/iLib`.
- The list type after a database import (`bb730af`) was run in the application under headless Wine,
  on AutoHotkey 1.1.37.02, at `ca8109b` and with the fixed text, by
  `.claude/scratch/import-sldb-list-type-2026-11-18/` (`fix3-tests.ahk`, `run-i.sh`; the logs in
  `results/`). Batch I goes through `addNewFile2list()`, the function of the Insert key, with its
  file dialog answered by the kit: a database picked on the welcome screen, with and without a
  saved list named `newFile.SLD` next to it, then with a saved list open and with a folder open; a
  file that is not a database and a database without images, both from the welcome screen. It
  reads the list type, the type text of the information box, the «Files list» menu and the context
  menu as built, the save panel's text and the box that the folders list panel's rename brings,
  and compares them with those of an unsaved list made by `coreAddNewFiles()`. Batch H
  passes with the fixed text. AutoHotkey 1.1.37.02 loads the fixed text, with and without `/iLib`.
- Small thing f (`5624fa8`) was run the same way, on the same interpreter and by the same kit, at
  `cd42beb` (before `ca8109b`), at `a560074` and with the fixed text. Batch S opens the tree with a
  folder open in QPV and selects in turn a folder with images, one with images and sub-folders, one
  on the disk with nothing to count, one removed from the disk after the tree was built, and the
  drive, then no element; after each it reads the status line, filled as the Space key and «Show
  folder details» fill it. Batch I passes with the fixed text, and AutoHotkey 1.1.37.02 loads it,
  with and without `/iLib`.
- Findings 5 to 12 were run in the application under headless Wine, on AutoHotkey 1.1.37.02, at
  `54c1996` and with the fixed texts, by `.claude/scratch/folders-tree-5-12-2026-11-18/`
  (`tests-5-12.ahk`, `run.sh`, `run-all.sh`; `mkfixes.py` writes one text per fix; the logs in
  `app/results/`). Batches T5 to T12, one per finding, call what the tree calls:
  `UIcoreFolderRename()` and F2, `UIcoreFolderPasteFoldersInto()`, the menu's two «selected file(s)»
  items, `folderTreeAppendFiles()`, F5, F9 and Space, with every box answered from a timer. Batch
  T13 goes through the omnibox: its F2, its F3 and «import folder» rows, its «Copy selected file(s)
  into...», a drop of files on one of its rows and a drag of one of its rows onto the tree. Four
  things are simulated by the kit. A drag: the button is reported as held for three checks, the
  pointer as over the tree or the omnibox, and the element or row under it is given;
  `FolderTreeResponder()`, `thumbsListClickResponder()` and `LVquickSearchMenusResponder()` then run
  as after a real drag; `thumbsListClickResponder()` was called with the image view showing, not the
  thumbnails view. The Alt key that `triggerQuickFileAction()` reads. Explorer, which is logged in
  place of being started. And the shell's copy or move of a folder, which the kit logs and does
  itself (finding 7). The folder of four characters is `C:\q`, in Wine's own `C:` drive, made and
  removed by the batch. Each batch was run at the text of its own fix, and all of them with the last
  text; of the seven checks of batch T13, five fail at `54c1996` and none with the last text;
  batches S, F3, H, I and G of the earlier kits give the same results with the last text as at
  `54c1996`. AutoHotkey 1.1.37.02 loads each of the eight texts, with and without `/iLib`. Not run:
  Windows itself, a real drag, a real Alt key.
- Findings 4 and 13 to 16 were run in the application under headless Wine, on AutoHotkey 1.1.37.02,
  at `b8b45c5` and with the fixed texts, by `.claude/scratch/folders-tree-4-13-16-2026-11-19/`
  (`tests-4-16.ahk`, `run.sh`, `run-all.sh`; `mkfixes.py` writes one text per fix; the logs in
  `app/results/`). Batches U4 and U13 to U16, one per finding, and U4x and U16x, two more cases of
  findings 4 and 16, call what the tree calls: F3 through `FolderTreeResponder()`, the drags as for
  findings 7 to 12, `folderTreeCutCopyFolder()` and the key Ctrl+X through `KeyboardResponder()`,
  `invokeFoldersListerMenu()` with the menus it builds read back, `folderTreeCreateFolder()` and the
  omnibox's F7, every box answered from a timer. The kit gives the Shift and Ctrl keys the tree
  reads; it logs Explorer and a new QPV instance in place of starting them, and the clipboard writes
  in place of making them; it does the shell's move itself. The tree was never built with no list
  loaded: batch U4 builds it with a folder open, then closes the list. In batch U4 «ERROR: Unable to
  display the image» follows some of the opens, other ones at each of three runs, and it follows
  plain opens at `b8b45c5` too (batch U4n): it is the display of the image under headless Wine, not
  the fixes. Each batch was run at the text of its own fix, and all of them with the last text;
  batches T5 to T13 (findings 5 to 12), F1, F2 and F4 (findings 1 and 2, decision 11), R, D, E, G
  and H (the sibling navigation, the short lists and the unsaved lists), S (small thing f) and I
  («Seen in passing» G) give the same results with the last text as at `b8b45c5`: every check passes
  at both, and batch R, which only logs, returns the same nine values. AutoHotkey 1.1.37.02 loads
  each of the five texts, with and without `/iLib`. Not run: Windows itself, a real drag, real keys.
- «Seen in passing» M to P were run the same way, at `35a7c94` and with the fixed texts, by
  `.claude/scratch/folders-tree-seen-m-p-2026-11-19/` (`tests-m-p.ahk`, `run.sh`, `run-all.sh`;
  `mkfixes-mp.py` writes one text per fix; the logs in `app/results/`). Batches VM, VN, VO and VP,
  one per entry, go through the omnibox's drags (`LVquickSearchMenusResponder()`, simulated as the
  tree's are), its F2, F3 and paste, the tree's «Cut folder» and «Paste folder(s) into...»,
  `folderTreeCreateFolder()`, the omnibox's list as `uiPopulateQuickMenuSearch()` builds it again,
  and the tooltips of an import and of a plain folder open; batches VPx, VNx and VOx, run at
  `35a7c94` and with the last text only, cover three more cases: the fallback scan, an omnibox move
  with the folders tree never opened, and a rename to «0» with the search and replace tick. The kit
  also gives the Shift key that the omnibox reads and the paste's clipboard text, and logs the
  emptying of the clipboard after a move in place of making it. Each batch was run at the text of
  its own fix, and all of them with the last text; batches U4, U4x, U13 to U16 and U16x (findings 4
  and 13 to 16), T5 to T13 (findings 5 to 12), F1, F2 and F4 (findings 1 and 2, decision 11), R, D,
  E, G and H (the sibling navigation, the short lists and the unsaved lists), S (small thing f) and
  I («Seen in passing» G) give the same results with the last text as at `35a7c94`: every check
  passes at both, and R, U4x and U16x, which only log, log the same lines. AutoHotkey 1.1.37.02
  loads each of the four texts, with and without `/iLib`.
- The open «small things» and «Seen in passing» were checked on 2026-11-19 at `15e9716`, in the
  application under headless Wine, on AutoHotkey 1.1.37.02, by
  `.claude/scratch/folders-tree-open-items-2026-11-19/` (`tests-open.ahk`, `run.sh`, `run-all.sh`;
  the logs in `app/results/`), with the helpers of the earlier kits. One batch per item: WSa, WSc,
  WSd, WSe and WSg for the small things, WPA, WPB, WPD, WPH, WPI, WPJ and WPQ for «Seen in
  passing»; K, L and the hidden window of Q by batches T14, T10 and VNx again. Each check states
  what should happen once the item is fixed, so it fails where the item holds; the controls of each
  batch pass, but for the click of the default button in batch WSe (small thing e). The kit writes
  a custom keys file in its own folder (c), turns the quick file actions on (d), posts the 7 key
  and Alt+D to the tree as window messages (d, e), marks lists as edited (g, «Seen in passing» B),
  deletes files in its work folder (J), and simulates the drags and the clipboard as the earlier
  kits do. Batch WSe ran at `a6b57e0` too, the text before small thing e's fix; `mnemonic/` holds a
  bare AutoHotkey window with the panel's layout (`layout.ahk`), which shows why Alt+D did nothing
  there. Not run: Windows itself, real keys and a real drag, the omnibox's rename (J), «Seen in
  passing» C.
- Small thing g (`4c6a16d`) was run in the application under headless Wine, on AutoHotkey 1.1.37.02,
  at `8ee6fef` and with the fixed text, by `.claude/scratch/folders-tree-small-g-2026-11-19/`
  (`tests-g.ahk`, `run.sh`, `run-regs.sh`; `mkfix-g.py` writes the text; the logs in `results/`),
  with the helpers of the earlier kits. Batch WSg of the open-items kit; batch WGa, Enter on an
  existing folder through `folderTreeDefaultAction()`, with the modified .SLD list of 212 files, 30
  selected, and the three answers in turn; batch WGu, the omnibox's «Open folder now» on a missing
  folder («Seen in passing» U). At `8ee6fef` WSg fails its check g1 and WGu its check gu1; with the
  fixed text WSg passes and WGu still fails, as U says; WGa passes at both, and its logs differ only
  by the logged call of `tryOpenGivenFolder()`, now made before the questions, with `askFirst` set
  to 1. Batches T6, T7, T9, T10, T12, T13, T15, U4, U4n, U4x, U13, VM, VP, WPB, WPD, WPQ, WSc and
  WSex of the earlier kits, the ones that go through the tree's and the omnibox's opens, imports and
  drags, give the same checks with the fixed text as at `8ee6fef`: those of WPB, WPD, WPQ and WSc
  fail at both, for «Seen in passing» B, D and Q and small thing c, which they check; U4n, U4x and
  WSex, which only log, log the same lines, but for that call and, in WSex, the window handles.
  AutoHotkey 1.1.37.02 loads the fixed text, with and without `/iLib`. Not run: Windows itself, real
  keys, the «Save image» question.
