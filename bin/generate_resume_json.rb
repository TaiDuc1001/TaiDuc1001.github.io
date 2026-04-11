#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require "optparse"

MONTH_MAP = {
  "jan" => 1,
  "january" => 1,
  "feb" => 2,
  "february" => 2,
  "mar" => 3,
  "march" => 3,
  "apr" => 4,
  "april" => 4,
  "may" => 5,
  "jun" => 6,
  "june" => 6,
  "jul" => 7,
  "july" => 7,
  "aug" => 8,
  "august" => 8,
  "sep" => 9,
  "sept" => 9,
  "september" => 9,
  "oct" => 10,
  "october" => 10,
  "nov" => 11,
  "november" => 11,
  "dec" => 12,
  "december" => 12
}.freeze

DEFAULTS = {
  bib_file: "_bibliography/_papers.bib",
  template_file: "assets/json/resume.template.json",
  output_file: "assets/json/resume.json",
  selected_only: false,
  include_types: %w[article inproceedings incollection],
  dry_run: false
}.freeze

def strip_wrappers(text)
  value = text.to_s.strip
  loop do
    break if value.length < 2

    wrapped_by_braces = value.start_with?("{") && value.end_with?("}")
    wrapped_by_quotes = value.start_with?("\"") && value.end_with?("\"")
    break unless wrapped_by_braces || wrapped_by_quotes

    value = value[1..-2].strip
  end
  value
end

def plain_text(text)
  value = strip_wrappers(text)
  value = value.gsub(/\r?\n/, " ")
  value = value.gsub(/\\([&#%_$\{\}])/, "\\1")
  value = value.gsub(/[{}]/, "")
  value = value.gsub("\\", "")
  value.gsub(/\s+/, " ").strip
end

def split_bib_entries(content)
  entries = []
  cursor = 0

  while (at_index = content.index("@", cursor))
    open_brace = content.index("{", at_index)
    break unless open_brace

    depth = 1
    index = open_brace + 1
    in_quotes = false
    escaped = false

    while index < content.length && depth.positive?
      char = content[index]

      if in_quotes
        if escaped
          escaped = false
        elsif char == "\\"
          escaped = true
        elsif char == "\""
          in_quotes = false
        end
      else
        case char
        when "\""
          in_quotes = true
        when "{"
          depth += 1
        when "}"
          depth -= 1
        end
      end

      index += 1
    end

    break unless depth.zero?

    entries << content[at_index...index]
    cursor = index
  end

  entries
end

def read_value(text, start_index)
  return ["", start_index] if start_index >= text.length

  char = text[start_index]

  if char == "{"
    depth = 1
    index = start_index + 1
    in_quotes = false
    escaped = false

    while index < text.length && depth.positive?
      current = text[index]

      if in_quotes
        if escaped
          escaped = false
        elsif current == "\\"
          escaped = true
        elsif current == "\""
          in_quotes = false
        end
      else
        case current
        when "\""
          in_quotes = true
        when "{"
          depth += 1
        when "}"
          depth -= 1
        end
      end

      index += 1
    end

    value = depth.zero? ? text[(start_index + 1)...(index - 1)] : text[(start_index + 1)..]
    [value.to_s, index]
  elsif char == "\""
    index = start_index + 1
    escaped = false

    while index < text.length
      current = text[index]
      if escaped
        escaped = false
      elsif current == "\\"
        escaped = true
      elsif current == "\""
        break
      end
      index += 1
    end

    value = text[(start_index + 1)...index].to_s
    index += 1 if index < text.length && text[index] == "\""
    [value, index]
  else
    index = start_index
    index += 1 while index < text.length && text[index] != "," && text[index] != "\n"
    [text[start_index...index].to_s, index]
  end
end

def parse_fields(body)
  fields = {}
  index = 0

  while index < body.length
    index += 1 while index < body.length && body[index].match?(/[\s,]/)
    break if index >= body.length

    name_start = index
    index += 1 while index < body.length && body[index].match?(/[A-Za-z0-9_-]/)
    break if name_start == index

    field_name = body[name_start...index].downcase
    index += 1 while index < body.length && body[index].match?(/\s/)
    next unless index < body.length && body[index] == "="

    index += 1
    index += 1 while index < body.length && body[index].match?(/\s/)

    value, index = read_value(body, index)
    fields[field_name] = value

    index += 1 while index < body.length && body[index].match?(/\s/)
    index += 1 if index < body.length && body[index] == ","
  end

  fields
end

def month_to_number(month_text)
  value = plain_text(month_text).downcase
  return 0 if value.empty?

  if value.match?(/\A\d{1,2}\z/)
    month_num = value.to_i
    return month_num if month_num.between?(1, 12)

    return 0
  end

  MONTH_MAP.fetch(value, 0)
end

def normalize_doi_to_url(doi_text)
  value = plain_text(doi_text)
  return nil if value.empty?

  value = value.gsub(%r{\Ahttps?://(?:dx\.)?doi\.org/}i, "")
  value = value.gsub(/\Adoi:\s*/i, "")
  value = value.strip
  return nil if value.empty?

  "https://doi.org/#{value}"
end

def normalize_url(text)
  value = plain_text(text)
  return nil if value.empty?

  return value if value.match?(%r{\Ahttps?://}i)
  return "https://#{value}" if value.start_with?("www.")

  doi_url = normalize_doi_to_url(value)
  return doi_url if doi_url

  value
end

def truthy?(text)
  value = plain_text(text).downcase
  %w[true yes 1 y].include?(value)
end

def first_present(*values)
  values.each do |value|
    return value if value && !value.empty?
  end
  nil
end

def format_release_date(year_number, month_number)
  year = year_number.to_i
  return "" if year <= 0

  return year.to_s if month_number.to_i <= 0

  format("%<year>04d-%<month>02d", year: year, month: month_number)
end

def parse_publications_from_bib(content, selected_only:, include_types:)
  entries = split_bib_entries(content)

  parsed = entries.filter_map do |entry|
    match = entry.match(/\A@([A-Za-z]+)\s*\{\s*([^,]+)\s*,(.*)\}\s*\z/m)
    next unless match

    entry_type = match[1].downcase
    next unless include_types.include?(entry_type)

    fields = parse_fields(match[3])
    next if selected_only && !truthy?(fields["selected"])

    title = plain_text(fields["title"])
    next if title.empty?

    year_text = plain_text(fields["year"])
    year_number = (year_text[/\d{4}/] || "0").to_i
    next if year_number <= 0

    month_number = month_to_number(fields["month"])

    publisher = if entry_type == "article"
      plain_text(fields["journal"])
    else
      plain_text(fields["booktitle"])
    end
    next if publisher.empty?

    publisher_link = if entry_type == "article"
      normalize_url(fields["journal_url"])
    else
      normalize_url(fields["booktitle_url"])
    end

    doi_url = normalize_doi_to_url(fields["doi"])
    title_url = first_present(
      normalize_url(fields["url"]),
      normalize_url(fields["html"]),
      doi_url,
      publisher_link,
      normalize_url(fields["website"]),
      normalize_url(fields["code"])
    )

    publication = {
      "citationKey" => plain_text(match[2]),
      "name" => title,
      "publisher" => publisher,
      "releaseDate" => format_release_date(year_number, month_number)
    }

    publication["url"] = title_url if title_url

    if entry_type == "article"
      publication["journal_url"] = publisher_link if publisher_link
    else
      publication["booktitle_url"] = publisher_link if publisher_link
    end

    publication["_sort_year"] = year_number
    publication["_sort_month"] = month_number

    publication
  end

  parsed
    .sort_by do |item|
      [
        -item["_sort_year"].to_i,
        -item["_sort_month"].to_i,
        item["name"].downcase
      ]
    end
    .map do |item|
      item.reject { |key, _value| key.start_with?("_sort_") }
    end
end

def build_options
  options = DEFAULTS.dup

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby bin/generate_resume_json.rb [options]"

    opts.on("--bib PATH", "Path to BibTeX file (default: #{DEFAULTS[:bib_file]})") do |path|
      options[:bib_file] = path
    end

    opts.on("--template PATH", "Path to template JSON (default: #{DEFAULTS[:template_file]})") do |path|
      options[:template_file] = path
    end

    opts.on("--output PATH", "Path to output resume JSON (default: #{DEFAULTS[:output_file]})") do |path|
      options[:output_file] = path
    end

    opts.on("--all", "Include all BibTeX entries (default)") do
      options[:selected_only] = false
    end

    opts.on("--selected-only", "Include only selected=true entries") do
      options[:selected_only] = true
    end

    opts.on("--types LIST", "Comma-separated BibTeX types (default: #{DEFAULTS[:include_types].join(',')})") do |types|
      options[:include_types] = types.split(",").map(&:strip).reject(&:empty?).map(&:downcase)
    end

    opts.on("--dry-run", "Print result to stdout, do not write file") do
      options[:dry_run] = true
    end
  end

  parser.parse!(ARGV)
  options
end

def resolve_template_path(template_path, output_path)
  return template_path if File.exist?(template_path)
  return output_path if File.exist?(output_path)

  nil
end

options = build_options

unless File.exist?(options[:bib_file])
  warn "BibTeX file not found: #{options[:bib_file]}"
  exit 1
end

template_path = resolve_template_path(options[:template_file], options[:output_file])
if template_path.nil?
  warn "Template JSON not found. Checked: #{options[:template_file]} and #{options[:output_file]}"
  exit 1
end

bib_content = File.read(options[:bib_file])
resume_data = JSON.parse(File.read(template_path))

publications = parse_publications_from_bib(
  bib_content,
  selected_only: options[:selected_only],
  include_types: options[:include_types]
)

resume_data["publications"] = publications
rendered = JSON.pretty_generate(resume_data) + "\n"

if options[:dry_run]
  puts rendered
  exit 0
end

FileUtils.mkdir_p(File.dirname(options[:output_file]))

if File.exist?(options[:output_file]) && File.read(options[:output_file]) == rendered
  puts "No changes detected for #{options[:output_file]}; resume JSON is up to date."
  exit 0
end

File.write(options[:output_file], rendered)
puts "Generated #{options[:output_file]} with #{publications.length} publication(s) from #{options[:bib_file]}."
