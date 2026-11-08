# Multi-rename panel: ideas for a friendlier pattern UI

Snapshot of 2026-11-08, branch `development` at `d9db8f8`. Ideas only; nothing here is implemented.

Scope: `PanelMultiRenameFiles()` (:40558) and the code that reads its patterns: `decideMultiRename()` (:40682),
`decideFinalMultiRename()` (:40804), the preview `uiPopulateLVmultiRename()` (:40910) and the batch
`coreBatchMultiRenameFiles()` (:41009). Line numbers are `quick-picto-viewer.ahk` at `d9db8f8` unless another file
is named; the function names are there to find each spot after the file changes.

## The problem

Everything goes into one box, a ComboBox that also lists the last 35 patterns. The rename method is picked silently
from what's typed: `$.` at the start, `//`, `\\` (works but isn't in the help, :40722), `>>`, or a plain name. The
rules are only in the Help message box (`BtnHelpMultiRename()`, :40658). The preview goes blank without saying why
when the pattern is too short, is just `[this]`, or has no search text.

Roughly what sections 1 and 3 would add:

```
Pattern: [Holiday [counter]               ] [Insert ▾] [Examples ▾]
         New name «Holiday» + a number across all 120 files → Holiday 1.jpg
┌ Original ─────┬ Renamed ──────┬ Status ─────────────┐
│ IMG_0042.jpg  │ Holiday 1.jpg │ OK                  │
│ IMG_0043.jpg  │ Holiday 2.jpg │ Name exists → Skip  │
└───────────────┴───────────────┴─────────────────────┘
118 will be renamed · 2 name conflicts · 0 unchanged
```

## 1. Small additions around the existing box

The renaming code stays the same.

- **«Insert ▾» button**, built like the «Possible source paths» triangle button in the structured copy/move panel
  (`BtnIdentifyFileRoots()`, :59734). It would show friendly names, each with an example value from the
  highlighted file:
  - File name: `[this]` (IMG_0042)
  - Parent folder name: `[pfdname]` (Vacation 2024)
  - Date modified / created: `[fDateM]` / `[fDateC]` (2026-11-08)
  - Number across all selected files, in list order: `[counter]`
  - File name with characters cut off…: asks for the two counts, then inserts `trim{X,Y}`
  - Letter case ▸ UPPER / lower / Title: `case{U}` / `case{L}` / `case{T}`
  - Find and replace… / Find and replace with a regular expression (RegEx)… / Replace single characters… /
    Change extension…: each fills the box with a template (`IMG_//Photo_`, `\>…//…`, ` >>_`, `$.jpg`) and selects
    the part to edit.
  - Tokens go in at the cursor (EM_REPLACESEL, 0xC2, sent to the combo's edit, which `GetComboBoxInfo()` already
    finds in `UIgenericComboAction()`, :40664).
  - Disable items that would do nothing there: tokens before `//` (they aren't replaced there), and everything once
    the box starts with `$.`.
- **«Examples ▾» menu** of ready patterns:
  - Text before the name: `New-[this]`
  - Text after it: `[this]-edited`
  - Name + number: `Holiday [counter]`
  - Folder + number: `[pfdname] [counter]`
  - Date + name: `[fDateM] [this]`
  - Remove text: `IMG_//`
  - Spaces → underscores: ` >>_`
  - Drop the first 4 characters: `trim{4,0}`
  - UPPERCASE: `case{U}`
  - New extension: `$.jpeg`
- **A plain-language line under the box** saying what the pattern will do, built from the values
  `decideMultiRename()` already returns. This is where the hidden rules show up:
  - `Holiday` → "New name «Holiday», numbered per folder: Holiday (1), Holiday (2)…"
  - `[counter]` → "File name + a number across all files: IMG_0042 (1)". The code turns it into
    `[this] ([counter])` (:40714).
  - `IMG_//Photo_` → "Find «IMG_» in any letter case, replace it with «Photo_»"
  - `a//b?c` → "Find «a» and **delete** it: the replacement has a character not allowed in file names".
    `filterFileName()` returns empty here (:40750); `>>` does the same (:40765).
  - `$.jpg` → "Give all files the .jpg extension; e.g. 30 PNG files stay PNG inside" (:41078)
  - It also gives the reason when the preview is empty: too short / `[this]` alone renames nothing / no search
    text / invalid RegEx.
- **Grey example text in the empty box** (a cue banner), e.g. `Holiday [counter]  ·  IMG_//Photo_  ·  $.jpg`, using
  `EM_SETCUEBANNER()` from `lib/shell-stuff.ahk:1631`.
- **Help with before → after examples** instead of the a)–e) text, one line per method, using the first selected
  file. Or a «Reference» tab (Tab3, as other panels use) listing Token | Meaning | Example from your files, where
  double-click inserts the token.

## 2. Bigger change: a «Method» dropdown or tabs

- Methods: New name / Find and replace / Replace characters / Trim / Letter case / Change extension, each with its
  own fields:
  - Find, Replace with, ☐ Regular expression
  - Remove [4] characters from the start and [0] from the end
  - New extension, with a note: "this only renames; use the format converter to convert"
- The fields **build the same pattern text**, so the renaming code, history and preview don't change.
- Picking a history entry fills the fields back in from the values `decideMultiRename()` returns (`newExtu`, the
  three replace modes `regExRemplaceMode` / `rechecherRemplaceMode` / `charsRemplaceMode`, `caseChange`,
  `TrimmingMode`, `leftTrimu` / `righttTrimu`).
- «New name» gets a Numbering choice: per folder (plain name) or across all files (`[counter]`). "No number" only
  works with `[this]` or `trim{}`, because a plain name always gets " (N)".
- This is the layout people know from PowerToys PowerRename.

## 3. A preview that explains itself

- Status column: OK / Name exists → the chosen collision action / Same new name as row N / Unchanged. Today unchanged
  files drop out of the list (:40992), and conflicts only show up during the rename.
- A summary line under the list (see the mock-up).
- Optionally, collapsible sections per status (ListView group view). `LV_EX_EnableGroupView()`,
  `LV_EX_GroupInsert()` and `LV_EX_SetGroup()` are in `lib/LV_EX.ahk` but unused. A «Show only problems» checkbox
  is the simpler alternative.
- A "Rows 1–9 100 of 25 000" label by the paging buttons, and F9–F12 in their tooltips; nothing in the panel
  mentions those keys (`UIlvMultiRenameResponder()`, :40864).
- Rename «Solo rename» to «Rename highlighted file only…». Add a note that a batch rename can be undone: the
  quick-action bar offers «Undo rename» afterwards (:41226).

## 4. Changes to the renaming code that a friendlier UI would bring up

- Match case for `//` and `>>`. The script never sets `StringCaseSense`, so `StrReplace` ignores letter case:
  `img//photo` also changes `IMG`.
- Counter start value and zero padding (e.g. `[counter:3]` → 001).
- A choice of date format for `[fDateM]` / `[fDateC]` (always yyyy-MM-dd).
- Changing only the extension's letter case. Today `$.jpg` is the only way, and it forces one extension on mixed
  formats.
- Friendlier token names (`[name]`, `[folder]`…), or friendly labels in the menu only. The print panel already uses a
  second style, `{fname}`.

## 5. Bugs noticed along the way (to confirm)

- **History doesn't save what was typed.** `coreBatchMultiRenameFiles()` passes its pattern by reference to
  `decideMultiRename()` (:41022), which removes `case{…}`, and that changed text is what
  `RecordUsedMultiRenamesQueriesManager()` saves (:41049). So `case{U}` alone is saved as `[this]`, which the panel
  then rejects. The history also trims leading and trailing spaces, so ` >>_` comes back as `>>_` and is rejected.
- **Preview paging is off.** `uiPopulateLVmultiRename()` compares `uiLVoffset`, a count of selected files set by
  `UImultiRenameChangeLVoffset()` (:40623), with positions in the whole list (:40963). Per-folder numbers also
  restart at 1 on later pages (:40979), so the preview can show «Holiday (1)» where the rename writes
  «Holiday (9101)».
- **«Erase history» loses the typed pattern.** `EraseMultiRenameHisto()` (:41258) closes and reopens the panel
  without asking.

## Open decisions

1. Which scope: the small additions (section 1), the Method layout (section 2), or both in stages?
2. With the Method layout, should the raw pattern box stay editable, become read-only, or hide behind an
   «Advanced» toggle?
3. Keep `[pfdname]`-style tokens with friendly menu labels only, or add new token names?
4. Are the section 4 changes to the renaming code in scope?
5. Should the three bugs in section 5 be fixed separately first?

## Appendix: how the pattern box is read

In the order `decideMultiRename()` checks:

1. Starts with `$.`: the rest is the new extension for every file; nothing else applies (:40692).
2. `case{U}`, `case{L}` or `case{T}` anywhere: removed from the pattern, then applied to the whole new name but not
   the extension (:40698, :40854). If nothing else is left, the pattern becomes `[this]`.
3. Exactly `[counter]`: becomes `[this] ([counter])` (:40714).
4. `//`, or else `\\`: find and replace (:40720). `\>` at the start makes the find part a RegEx (:40738). Tokens and
   `trim{}` work only in the replace part, and anything after a second `//` is ignored. A plain find ignores letter
   case.
5. Else `>>`: each character before it is replaced by the text after it, and empty text removes them (:40759,
   `ChrReplace()` :40794). Tokens work after `>>`.
6. Otherwise, a new name. Tokens: `[this]`, `[pfdname]`, `[fDateM]`, `[fDateC]` (yyyy-MM-dd), `[counter]`,
   `trim{X,Y}`.
   - Without `[this]`, `trim{}` or `[counter]`, " (N)" is appended, N counting per folder (:40726, :40814).
   - `[counter]` counts all selected files in list order (:40729, :40985).
   - `trim{X,Y}` is the original name without X characters at the start and Y at the end; both numbers are
     required (:40719, :40842).

Also:
- In a plain `//` replace part and after `>>`, text with a character not allowed in file names becomes empty, so
  the match is deleted (:40750, :40765). A RegEx replace part is not checked.
- The preview stays blank for an empty pattern or just `[this]` (:40915), for under 2 characters or an empty find
  part (:40937), and shows a single «Invalid RegEx» row for a bad RegEx (:40925).
