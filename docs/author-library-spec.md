# 作者資訊庫規格 (Author Library Spec)

## 概述

作者資訊庫（Author Library）是古典詩文圖書館的核心子系統，集中管理所有作者（貢獻者）的元資料和傳記文章。

### 設計動機

現有系統的問題：
- `data/authors.yaml` 是平面的 YAML 檔案，只有姓名、朝代、bio 三個欄位
- `author-brief.md` 散布在 260 個文字目錄中，同一作者的相同簡介重複數十次（如李白 A018 重複 8 次）
- 無法追蹤文章來源（哪個出版物、誰寫的）
- 無法容納同一作者的多篇文章（不同出版物提供的簡介長度和角度不同）
- 姓名錯誤難以發現（如 A025 杜荀鶴的 bio 是王建的）

### 設計原則

1. **一作者一資料夾**：每位作者佔一個資料夾，資料夾名 = `{ref}_{姓名}`
2. **元資料與文章分離**：`author.yaml` 存結構化元資料，文章用 Markdown 檔案
3. **來源可追溯**：每篇文章的 frontmatter 記錄來源出版物和類型
4. **多文章共存**：同一作者可有多篇不同來源的傳記文章
5. **向下相容**：保留 A-number / C-number / 特殊鍵（Laozi 等）的引用系統

---

## 目錄結構

```
library/authors/
  A001_項羽/
    author.yaml
    brief-積累與感興.md
  A018_李白/
    author.yaml
    brief-積累與感興.md
    brief-積學與涵泳.md
    brief-NSS.md
  A148_孔子/
    author.yaml
    brief-積累與感興.md
    brief-積學與涵泳.md
    brief-NSS.md
    brief-郁文華章.md
  A153_禮記/
    author.yaml
  C001_王弼/
    author.yaml
  C003_李世民/
    author.yaml
    brief-帝範.md
  Laozi/
    author.yaml
    brief-河上公章句.md
```

---

## author.yaml 格式

每位作者的元資料檔案。

```yaml
id: A018                          # 引用鍵（A/C/Laozi 等）
name: 李白                        # 主要姓名
alt_names:                        # 別名、字號
  - 李太白
  - 青蓮居士
courtesy_name: 太白               # 字
pseudonym: 青蓮居士                # 號
dynasty: 唐                       # 朝代
dates:                            # 生卒年（可選，用於結構化查詢）
  birth: 701
  death: 762
  approximate: true               # 生卒年是否為約數
birth_place: 碎葉城（今吉爾吉斯斯坦） # 籍貫
tags:                             # 標籤（可選，用於分類和篩選）
  - 詩人
  - 浪漫主義
works:                            # 代表作（可選）
  - 將進酒
  - 靜夜思
```

### author.yaml 欄位說明

| 欄位 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `id` | string | 是 | 引用鍵，如 `A018`、`C003`、`Laozi` |
| `name` | string | 是 | 主要姓名（中文） |
| `alt_names` | string[] | 否 | 別名、又稱 |
| `courtesy_name` | string | 否 | 字 |
| `pseudonym` | string | 否 | 號 |
| `dynasty` | string | 是 | 朝代 |
| `dates` | object | 否 | 生卒年結構化資料 |
| `dates.birth` | number | 否 | 出生年（公元） |
| `dates.death` | number | 否 | 卒年（公元） |
| `dates.approximate` | boolean | 否 | 生卒年是否為約數 |
| `birth_place` | string | 否 | 籍貫 |
| `tags` | string[] | 否 | 分類標籤 |
| `works` | string[] | 否 | 代表作列表 |

### 特殊作者類型

某些「作者」實際上是文獻名（如禮記、尚書），或是一個群體（如佚名）：

```yaml
# 文獻名
id: A153
name: 禮記
dynasty: 周
tags:
  - 文獻

# 佚名
id: A102
name: 佚名
dynasty: null

# 群體作者
id: A149
name: 老子
alt_names:
  - 李耳
  - 老聃
dynasty: 周
```

---

## 文章檔案格式

每位作者可有多篇傳記文章，每篇是一個 Markdown 檔案。

### 命名規則

```
{type}-{source}.md
```

- `type`: 文章類型（`brief`=簡介、`bio`=詳傳、`intro`=導論）
- `source`: 來源出版物名稱（不含空格）

範例：
- `brief-積累與感興.md`
- `brief-積學與涵泳.md`
- `brief-NSS.md`
- `bio-維基百科.md`
- `intro-中國文學史.md`

### 文章 frontmatter

```yaml
---
title: 作者簡介                # 文章標題
type: brief                    # brief | bio | intro
source:                        # 來源資訊
  publication: 積累與感興       # 出版物名
  publisher: 教育局課程發展處   # 出版者
  collection: primary          # 所屬文集（primary/secondary/nss 等）
collection_refs:               # 此文章所服務的 text.cham.md 檔案
  - primary/031_靜夜思
  - primary/032_送友人
  - primary/033_黃鶴樓送孟浩然之廣陵
---
文章正文...
```

### 文章 frontmatter 欄位說明

| 欄位 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `title` | string | 是 | 文章標題 |
| `type` | string | 是 | `brief`（簡介）、`bio`（詳傳）、`intro`（導論） |
| `source.publication` | string | 是 | 出版物名 |
| `source.publisher` | string | 否 | 出版者 |
| `source.collection` | string | 否 | 所屬文集 ID |
| `collection_refs` | string[] | 否 | 引用此文章的 text.cham.md 路徑 |

---

## 與現有系統的整合

### 引用方式不變

`text.cham.md` 中的 `contributors.ref` 仍然使用 A/C 鍵或特殊鍵：

```yaml
contributors:
  - ref: A018
    role: author
```

管線在構建時查詢 `library/authors/A018_李白/author.yaml` 取得元資料。

### author-brief.md 去重

遷移後，各 content 目錄下的 `author-brief.md` 應改為指標檔案：

```yaml
---
title: 作者簡介
subject:
  type: author
  ref: A018
source_ref: authors/A018_李白/brief-積累與感興.md
---
```

或者完全移除，由管線在構建時自動從作者庫查找對應文章。

### authors.yaml 遷移

現有 `data/authors.yaml` 的每一個條目遷移為：
- `library/authors/{id}_{name}/author.yaml`（元資料）
- `library/authors/{id}_{name}/brief-{source}.md`（bio 欄位的內容，如有）

遷移完成後，`data/authors.yaml` 可保留作為索引或完全廢棄。

---

## 查詢場景

### 場景 1：前端展示作者簡介

```
用戶瀏覽 → primary/031_靜夜思 → 作者「李白」
→ 管線查詢 authors/A018_李白/author.yaml（姓名、朝代）
→ 管線查找 authors/A018_李白/brief-積累與感興.md（當前文集對應的簡介）
→ 前端渲染
```

### 場景 2：作者詳情頁

```
用戶點擊「李白」→ 作者詳情頁
→ 讀取 author.yaml（元資料）
→ 讀取所有 brief-*.md / bio-*.md（列出所有來源的簡介）
→ 展示多個版本的傳記
```

### 場景 3：跨文集查找

```
用戶在 NSS 文集查看「師說」→ 作者「韓愈」
→ 查詢 A026_韓愈/author.yaml
→ 優先查找 brief-NSS.md（NSS 文集專用簡介）
→ 回退到 brief-積學與涵泳.md（如果 NSS 版本不存在）
```

---

## 實作計劃

### Phase 1：建立作者庫結構

1. 建立 `library/authors/` 目錄
2. 為每個 authors.yaml 條目建立對應的 `author.yaml`
3. 從各文集的 `author-brief.md` 去重、提取文章
4. 按來源出版物命名文章檔案

### Phase 2：管線整合

1. 更新 `library-pipeline.ts` 讀取 `library/authors/` 而非 `data/authors.yaml`
2. 文集構建時自動匹配正確的簡介文章（按 collection 優先匹配）
3. 輸出 `authors.json` 供前端使用

### Phase 3：遷移完成

1. 將各 content 目錄的 `author-brief.md` 改為指標檔案或移除
2. 廢棄 `data/authors.yaml`
3. 更新驗證腳本

---

## 統計

| 項目 | 數量 |
|------|------|
| 唯一作者引用鍵 | ~171 |
| author-brief.md 檔案（去重前） | 260 |
| 預計去重後文章數 | ~50-60（多個文集共享同一作者） |
| authors.yaml 條目 | ~166 |
