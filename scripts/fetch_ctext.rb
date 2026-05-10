#!/usr/bin/env ruby
# frozen_string_literal: true

# ctext.org importer — fetches classical Chinese texts from archive.org
# snapshots and generates CHAM (Classical Han with Annotations Markup) files.
#
# Uses the archaeo gem (>= 0.2.3) for all Wayback Machine interaction:
#   - Archaeo::CdxApi          — find latest snapshot per page
#   - Archaeo::Fetcher         — download archived pages
#   - Archaeo::RateLimitError  — specific 503 handling
#
# Usage:
#   ruby fetch_ctext.rb --book heshanggong --config configs/heshanggong.yaml
#   ruby fetch_ctext.rb --book heshanggong --start 35 --end 81 --force
#   ruby fetch_ctext.rb --book heshanggong --page 1 --dry-run

require "nokogiri"
require "archaeo"
require "optparse"
require "fileutils"
require "yaml"

CDX     = Archaeo::CdxApi.new
FETCHER = Archaeo::Fetcher.new

# --- ctext.org HTML parsing ---

module CtextParser
  module_function

  # Parse a <td class="ctext"> into [[text, [comments]], ...] pairs
  def parse_ctext_cell(td)
    segments = []
    current_text = ""
    current_comments = []

    flush = -> {
      if !current_text.empty? && !current_comments.empty?
        segments << [current_text, current_comments.dup]
      elsif !current_text.empty?
        segments << [current_text, []]
      elsif !current_comments.empty? && segments.any?
        last = segments.last
        segments[-1] = [last[0], last[1] + current_comments.dup]
      end
      current_text = ""
      current_comments = []
    }

    td.children.each do |child|
      case child
      when Nokogiri::XML::Text
        text = child.text
        next if text.strip.empty?
        flush.call unless current_comments.empty?
        current_text += text
      when Nokogiri::XML::Element
        if child.name == "span" && (child["class"] || "").include?("inlinecomment")
          comment = child.text.strip
          current_comments << comment unless comment.empty?
        else
          text = child.text
          next if text.strip.empty?
          flush.call unless current_comments.empty?
          current_text += text
        end
      end
    end
    flush.call
    segments
  end

  def parse_page(html)
    doc = Nokogiri::HTML(html)
    title = nil
    content_tds = []

    doc.css("td").each do |td|
      cls = (td["class"] || "").split
      if cls.include?("ctext") && cls.include?("opt")
        title = td.text.strip.gsub(/[：:]+$/, "")
      elsif td["class"] == "ctext"
        content_tds << td
      end
    end

    return [title, []] if content_tds.empty?
    segments = content_tds.flat_map { |td| parse_ctext_cell(td) }
    [title, segments]
  end

  def clean_text(text)
    text.strip.gsub("　", "").gsub(/\s+/, "")
  end
end

# --- CHAM generation ---

module ChamWriter
  module_function

  def write_book(output_dir, book_id, config)
    title_zh = config["title_zh"] || book_id
    title_en = config["title_en"] || book_id

    yaml = {
      "id" => book_id,
      "title" => title_zh,
      "titleEn" => title_en,
      "publisher" => "ctext.org",
      "genre" => "prose",
    }
    yaml["contributors"] = config["contributors"] if config["contributors"]
    yaml["date"] = config["date"] if config["date"]
    yaml["layers"] = config["layers"] if config["layers"]
    yaml["annotation"] = { "defaultLabel" => "原文", "defaultShortLabel" => "文" }

    File.write(File.join(output_dir, "book.yaml"), yaml.to_yaml.sub(/^---\n/, ""))
    puts "Written book.yaml"
  end

  def write_chapter(output_dir, page_info, book_id, config, segments, dry_run:)
    num = page_info[:num]
    title = page_info[:title] || page_info[:label] || num.to_s
    layer_id = config.dig("layers", 0, "id") || "commentary"
    contributor = config.dig("layers", 0, "contributor") || "C000"
    dir_name = format("%03d_%s", num, title.gsub(%r{[/\\]}, "_"))
    chapter_dir = File.join(output_dir, dir_name)

    # text.cham.md frontmatter
    lines = ["---", "id: #{num}", "title: #{title}"]
    if config["contributors"]
      lines << "contributors:"
      config["contributors"].each { |c| lines << "  - ref: #{c['ref']}\n    role: #{c['role']}" }
    end
    if config["date"]
      lines << "date:"
      config["date"].each { |k, v| lines << "  #{k}: #{v}" }
    end
    lines += ["genre: prose", "source:", "  textRef: #{book_id}", "  relation: section", "---", ""]

    marker = 0
    text_lines = []
    commentary_lines = []

    segments.each do |text, comments|
      cleaned = CtextParser.clean_text(text)
      next if cleaned.empty?
      if comments.any?
        marker += 1
        text_lines << "{#{marker}}#{cleaned}{/#{marker}}"
        commentary_lines << "{#{marker}} commentary [#{comments.join(' ')}]"
      else
        text_lines << cleaned
      end
      text_lines << ""
    end
    commentary_lines << "" unless commentary_lines.empty?

    text_content = (lines + text_lines).join("\n")
    commentary_content = [
      "---", "type: secondary", "base: text.cham.md",
      "contributor: #{contributor}", "role: commentator",
      "nature: commentary", "---", "", "## 注釋",
      *commentary_lines
    ].join("\n")

    if dry_run
      puts "\n=== Page #{num}: #{title} ==="
      puts text_content
      puts commentary_content
      return
    end

    FileUtils.mkdir_p(chapter_dir)
    File.write(File.join(chapter_dir, "text.cham.md"), text_content)
    File.write(File.join(chapter_dir, "#{layer_id}.cham.md"), commentary_content)
    puts "  Written #{dir_name}: #{marker} annotation(s)"
  end
end

# --- Fetching with archaeo ---

def fetch_page(ctext_book, num)
  url_path = "ctext.org/#{ctext_book}/#{num}"

  snapshot = CDX.newest(url_path)
  unless snapshot
    puts "  No snapshot found for #{url_path}"
    return nil
  end

  puts "  Snapshot: #{snapshot.timestamp} (#{snapshot.status_code})"
  page = FETCHER.fetch("https://#{url_path}", timestamp: snapshot.timestamp.to_s)

  return page.content if page.status_code == 200 &&
    (page.content.include?("inlinecomment") || page.content.include?('<td class="ctext"'))

  puts "  Warning: page has no ctext content (status=#{page.status_code})"
  nil
rescue Archaeo::RateLimitError => e
  puts "  Rate limited, will retry: #{e.message}"
  :rate_limited
rescue Archaeo::Error => e
  puts "  Archaeo error: #{e.message}"
  nil
end

def discover_pages(ctext_book)
  url_path = "ctext.org/#{ctext_book}"
  puts "Discovering pages from #{url_path}..."

  begin
    snapshot = CDX.newest(url_path)
    unless snapshot
      puts "  No index snapshot found"
      return []
    end

    page = FETCHER.fetch("https://#{url_path}", timestamp: snapshot.timestamp.to_s)
    doc = Nokogiri::HTML(page.content)
  rescue Archaeo::RateLimitError => e
    puts "  Rate limited: #{e.message}"
    return []
  rescue => e
    puts "  Index fetch failed: #{e.message}"
    return []
  end

  pages = []
  seen = Set.new
  doc.css("a[href]").each do |a|
    href = a["href"]
    next unless href =~ %r{(?:^|/)#{ctext_book}/(\d+)$}
    num = $1.to_i
    next if seen.include?(num)
    seen << num
    pages << { num: num, label: a.text.strip }
  end
  pages.sort_by! { |p| p[:num] }

  if pages.any?
    puts "  Found #{pages.length} pages (#{pages.first[:num]}–#{pages.last[:num]})"
  else
    puts "  No pages found in index"
  end
  pages
end

# --- Main ---

options = {
  output_dir: nil, start: nil, end_ch: nil,
  delay: 2, dry_run: false, book: nil, force: false, config_file: nil
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} --book BOOK [options]"
  opts.on("--book BOOK",     "ctext.org URL path (e.g. heshanggong)")  { |v| options[:book] = v }
  opts.on("--output-dir DIR","Output directory (default: ../content/<book>)") { |v| options[:output_dir] = v }
  opts.on("--start N", Integer, "First page number")  { |v| options[:start] = v }
  opts.on("--end N",   Integer, "Last page number")   { |v| options[:end_ch] = v }
  opts.on("--page N",  Integer, "Fetch single page")  { |v| options[:start] = options[:end_ch] = v }
  opts.on("--delay SECS",Float,  "Delay between requests (default: 2)") { |v| options[:delay] = v }
  opts.on("--dry-run",  "Print output without writing files") { options[:dry_run] = true }
  opts.on("--force",    "Re-download even if page exists")    { options[:force] = true }
  opts.on("--config FILE","YAML config for book metadata")    { |v| options[:config_file] = v }
end
parser.parse!

unless options[:book]
  $stderr.puts "Error: --book is required.\n\n#{parser}"
  exit 1
end

ctext_book = options[:book]
config = options[:config_file] ? (YAML.load_file(options[:config_file]) || {}) : {}
book_id = config["id"] || ctext_book
output_dir = File.expand_path(options[:output_dir] || File.join(__dir__, "..", "content", book_id))

# Discover or build page list
pages = discover_pages(ctext_book)
pages = pages.select { |p| p[:num] >= options[:start] } if options[:start]
pages = pages.select { |p| p[:num] <= options[:end_ch] } if options[:end_ch]

if pages.empty? && options[:start] && options[:end_ch]
  pages = (options[:start]..options[:end_ch]).map { |n| { num: n, label: n.to_s } }
end

unless pages.any?
  $stderr.puts "Error: no pages to fetch. Use --start/--end or fix discovery."
  exit 1
end

puts "\nImporting '#{ctext_book}' (id: #{book_id}) — #{pages.length} pages via archaeo"
puts "Output: #{output_dir}"
puts "(dry run)" if options[:dry_run]

unless options[:dry_run]
  FileUtils.mkdir_p(output_dir)
  ChamWriter.write_book(output_dir, book_id, config)
end

errors = []
max_retries = 3

pages.each do |page_info|
  num = page_info[:num]
  dir_name = format("%03d_%s", num, (page_info[:title] || page_info[:label] || num.to_s).gsub(%r{[/\\]}, "_"))
  chapter_dir = File.join(output_dir, dir_name)

  if !options[:force] && !options[:dry_run] &&
     File.directory?(chapter_dir) && File.exist?(File.join(chapter_dir, "text.cham.md"))
    puts "  Skipping page #{num} (exists)"
    next
  end

  puts "\nPage #{num}:"

  retries = 0
  html = nil
  loop do
    html = fetch_page(ctext_book, num)
    break if html != :rate_limited
    retries += 1
    if retries <= max_retries
      wait = options[:delay] * (2 ** retries)
      puts "  Retry #{retries}/#{max_retries} in #{wait}s..."
      sleep(wait)
    else
      puts "  Max retries reached for page #{num}"
      html = nil
      break
    end
  end

  if html
    title, segments = CtextParser.parse_page(html)
    page_info[:title] = title if title && !title.empty?
    if segments.any?
      ChamWriter.write_chapter(output_dir, page_info, book_id, config, segments, dry_run: options[:dry_run])
    else
      puts "  WARNING: no segments parsed"
      errors << num
    end
  else
    errors << num
  end

  sleep(options[:delay])
end

if errors.any?
  $stderr.puts "\nErrors in pages: #{errors}"
  $stderr.puts "Retry: #{$0} --book #{ctext_book} --start #{errors.first} --end #{errors.last} --force"
else
  puts "\nDone. All #{pages.length} pages processed."
end
