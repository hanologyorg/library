# ctext.org Importer

Fetches classical Chinese texts from [ctext.org](https://ctext.org) via
[archive.org](https://web.archive.org) snapshots and generates
[CHAM](https://github.com/riboseinc/cham-format) files.

Uses [archaeo](https://github.com/riboseinc/archaeo) (>= 0.2.3) for all
Wayback Machine interaction — snapshot discovery, content fetching,
retries, and rate-limit handling.

## Requirements

```bash
gem install archaeo nokogiri
```

## Usage

```bash
# Import all pages (auto-discovers from index, uses config for metadata)
ruby scripts/fetch_ctext.rb --book heshanggong --config scripts/configs/heshanggong.yaml

# Import a specific range
ruby scripts/fetch_ctext.rb --book heshanggong --start 35 --end 81 --config scripts/configs/heshanggong.yaml

# Import a single page (dry-run to preview)
ruby scripts/fetch_ctext.rb --book heshanggong --page 1 --dry-run

# Force re-download of existing pages
ruby scripts/fetch_ctext.rb --book heshanggong --force --config scripts/configs/heshanggong.yaml
```

## Options

| Flag | Description |
|------|-------------|
| `--book BOOK` | ctext.org URL path (required), e.g. `heshanggong` |
| `--config FILE` | YAML file with book metadata (id, contributors, layers, etc.) |
| `--output-dir DIR` | Output directory (default: `../content/<id>`) |
| `--start N` | First page number |
| `--end N` | Last page number |
| `--page N` | Fetch a single page |
| `--delay SECS` | Delay between requests (default: 2) |
| `--dry-run` | Print output without writing files |
| `--force` | Re-download even if page already exists |

## Book Configuration

A YAML config sets book-level metadata. The `id` field determines the
output directory name (default: `content/<id>`) and is used as `textRef`
in generated CHAM files.

Example (`scripts/configs/heshanggong.yaml`):

```yaml
id: heshanggong-laozi
title_zh: 老子河上公章句
title_en: Laozi with He Shang Gong Commentary

contributors:
  - ref: Laozi
    role: author

date:
  dynasty: 漢
  circa: true

layers:
  - id: heshanggong
    label: 河上公註
    shortLabel: 河
    annotator: 河上公
    contributor: C002
    role: commentator
    nature: commentary
    displayOrder: 1
```

### Key config fields

| Field | Purpose |
|-------|---------|
| `id` | Book identifier — output dir defaults to `content/<id>`, used as `textRef` |
| `title_zh` / `title_en` | Book title in Chinese/English for `book.yaml` |
| `contributors` | Author/annotator references in `book.yaml` and chapter frontmatter |
| `date` | Dynasty metadata |
| `layers` | Commentary layer definitions (id, label, contributor) |

If `id` is omitted, the `--book` value (ctext URL path) is used.

## How It Works

1. **Snapshot discovery**: `Archaeo::CdxApi#newest` finds the latest
   archived snapshot of each page.
2. **Content fetch**: `Archaeo::Fetcher#fetch` downloads archived HTML
   with built-in retries and rate-limit handling.
3. **Rate-limit retry**: On `Archaeo::RateLimitError` (HTTP 503),
   the script retries with exponential backoff (up to 3 retries).
4. **HTML parsing**: Extracts text segments and `<span class="inlinecomment">`
   commentary from ctext.org's HTML tables.
5. **CHAM generation**: Creates `text.cham.md` (base text with `{N}...{/N}`
   markers) and a subordinate commentary `.cham.md` per chapter.

## Adding a New Book

1. Find the book's URL path on ctext.org (e.g. `daodejing`, `zhuangzi`).
2. Create a config YAML in `scripts/configs/`.
3. Run:

```bash
ruby scripts/fetch_ctext.rb --book <path> --config scripts/configs/<path>.yaml
```

The script auto-discovers pages from the book's index. If discovery fails,
use `--start` and `--end` to specify the range manually.

## Architecture

```
fetch_ctext.rb
├── CtextParser      — HTML → segments (ctext.org-specific parsing)
├── ChamWriter       — segments → CHAM files (format generation)
├── fetch_page()     — CDX lookup + fetch (delegates to archaeo)
├── discover_pages() — index page parsing for chapter discovery
└── main             — CLI, orchestration, retry logic
```

All Wayback Machine interaction is delegated to archaeo.
Only ctext.org HTML parsing and CHAM generation are custom code.
