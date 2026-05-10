# Task 2: Create CHAM folder for 老子河上公章句 (Wikisource)

**Source**: `resources/wikisource/老子河上公章句.epub`
**Target**: `content/laozi-heshanggong-wiki/`

Steps:
- [x] Extract text from epub XHTML (3 files: intro, 道經, 德經)
- [x] Parse chapter structure (道經 37 chapters, 德經 44 chapters = 81 total)
- [x] Create book.yaml
- [x] Create chapter folders with text.cham.md + heshanggong.cham.md files
- [ ] Validate using cham library

Notes:
- Heshanggong uses same standard chapter order (道經 first)
- Each chapter has base text + commentary interleaved (〈...〉 markers)
- Chapter titles differ from standard: 體道, 養身, 安民, etc.
