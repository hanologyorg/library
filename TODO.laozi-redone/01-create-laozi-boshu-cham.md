# Task 1: Create CHAM folder for 帛書校勘版 (base text)

**Source**: `resources/wikisource/老子_(帛書校勘版).epub`
**Target**: `content/laozi-boshu/`

Steps:
- [x] Extract text from epub XHTML
- [x] Parse chapter structure (德篇 ch1-44, 道篇 ch45-81)
- [x] Create book.yaml
- [x] Create chapter folders with text.cham.md files
- [ ] Validate using cham library

Notes:
- Boshu chapter numbering differs from standard (德篇 first, then 道篇)
- Standard chapter numbers in parentheses for cross-referencing
- Chapter titles: 論德, 得一, 聞道, etc.
- Boshu text uses variant characters (亓 for 其, 恆 for 常, etc.)
