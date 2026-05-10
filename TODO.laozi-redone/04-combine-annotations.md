# Task 4: Combine annotations into 帛書校勘版

**Base**: `content/laozi-boshu/` (Task 1)
**Annotation 1**: `content/laozi-heshanggong-wiki/` (Task 2)
**Annotation 2**: `content/laozi-wangbi-wiki/` (Task 3)

Steps:
- [ ] Add 河上公章句 annotations to each boshu chapter
- [ ] Add 王弼本 annotations to each boshu chapter
- [ ] Map boshu chapter numbers to standard chapter numbers
- [ ] Align annotations to boshu base text (text differs between versions)
- [ ] Update book.yaml with annotation layers
- [ ] Validate

Key mapping (boshu → standard):
- Boshu 德篇 ch1-44 = standard ch38-81
- Boshu 道篇 ch45-81 = standard ch1-37
- Standard ch1 = boshu ch45 (觀道)
- Standard ch38 = boshu ch1 (論德)
