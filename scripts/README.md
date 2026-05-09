# ctext.org Importer

Fetches classical Chinese texts from [ctext.org](https://ctext.org) via
[archive.org](https://web.archive.org) snapshots and generates
[CHAM](https://github.com/riboseinc/cham-format) files.

Uses the [archaeo](https://github.com/riboseinc/archaeo) gem for all
Wayback Machine interaction — snapshot discovery, content fetching,
retries, and rate-limit handling.

## Requirements

```bash
gem install archaeo nokogiri
```

## Usage

```bash
# Import all pages of a book (auto-discovers pages from index)
ruby scripts/fetch_ctext.rb --book heshanggong

# Import a specific range
ruby scripts/fetch_ctext.rb --book heshanggong --start 35 --end 81

# Import a single page (dry-run to preview)
ruby scripts/fetch_ctext.rb --book heshanggong --page 1 --dry-run

# With a config file for book metadata
ruby scripts/fetch_ctext.rb --book heshanggong --config scripts/configs/heshanggong.yaml

# Force re-download of existing pages
ruby scripts/fetch_ctext.rb --book heshanggong --force
```

## Options

| Flag | Description |
|------|-------------|
| `--book BOOK` | ctext.org URL path (required), e.g. `heshanggong` |
| `--config FILE` | YAML file with book metadata (contributors, layers, etc.) |
| `--output-dir DIR` | Output directory (default: `../content/<book>`) |
| `--start N` | First page number |
| `--end N` | Last page number |
| `--page N` | Fetch a single page |
| `--delay SECS` | Delay between requests (default: 2) |
| `--dry-run` | Print output without writing files |
| `--force` | Re-download even if page already exists |

## Book Configuration

Create a YAML config to set book-level metadata in the generated CHAM files.

Example (`scripts/configs/heshanggong.yaml`):

```yaml
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

## How It Works

1. **Snapshot discovery**: Uses `Archaeo::CdxApi#newest` to find the latest
   archived snapshot of each page on archive.org.
2. **Content fetch**: Uses `Archaeo::Fetcher#fetch` to download the archived
   HTML (with built-in retries and rate-limit handling).
3. **HTML parsing**: Extracts text segments and `<span class="inlinecomment">`
   commentary from ctext.org's HTML tables.
4. **CHAM generation**: Creates `text.cham.md` (base text with `{N}...{/N}`
   markers) and a subordinate commentary `.cham.md` file per page.

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
├── CtextParser    — HTML → segments parsing (ctext.org-specific)
├── ChamWriter     — segments → CHAM files (format-specific)
├── fetch_page()   — archaeo CDX + Fetcher (delegate to gem)
├── discover_pages() — archaeo CDX + Fetcher for index (delegate to gem)
└── main           — CLI option parsing, orchestration
```

All Wayback Machine interaction is delegated to archaeo.
Only ctext.org HTML parsing and CHAM generation are custom code.
