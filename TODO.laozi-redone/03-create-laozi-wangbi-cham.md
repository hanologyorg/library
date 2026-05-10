# Task 3: Create CHAM folder for 道德經王弼本 (Wikisource)

**Source**: `resources/wikisource/道德經_(王弼本).epub`
**Target**: `content/laozi-wangbi-wiki/`

Steps:
- [x] Extract text from epub XHTML
- [x] Parse chapter structure (81 chapters, standard order)
- [x] Create book.yaml
- [x] Create chapter folders with text.cham.md + wangbi.cham.md files
- [ ] Validate using cham library

Notes:
- Wang Bi uses standard chapter order (道經 first)
- Base text + commentary interleaved (〈...〉 markers)
- No chapter titles, just numbered: 一章, 二章, etc.
