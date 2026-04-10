#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "yaml"

bib_file = ARGV[0] || "_bibliography/_papers.bib"
template_file = ARGV[1] || "assets/latex/template.tex"
output_file = ARGV[2] || "assets/latex/cv.tex"
config_file = ARGV[3] || "_config.yml"

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

def read_file_if_exists(path)
  return nil unless File.exist?(path)

  File.read(path)
end

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

def latex_escape(text)
  replacements = {
    "\\" => "\\textbackslash{}",
    "{" => "\\{",
    "}" => "\\}",
    "$" => "\\$",
    "&" => "\\&",
    "#" => "\\#",
    "%" => "\\%",
    "_" => "\\_",
    "~" => "\\textasciitilde{}",
    "^" => "\\textasciicircum{}"
  }

  text.to_s.each_char.map { |char| replacements.fetch(char, char) }.join
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

def normalize_name(text)
  return "" if text.to_s.empty?

  normalized = plain_text(text)
  normalized = normalized.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "")
  normalized = normalized.downcase
  normalized = normalized.gsub(/[^a-z0-9 ]/, " ")
  normalized.gsub(/\s+/, " ").strip
end

def month_to_number(month_text)
  value = plain_text(month_text).downcase
  return 0 if value.empty?

  if value.match?(/\A\d{1,2}\z/)
    month_num = value.to_i
    return 0 unless month_num.between?(1, 12)

    return month_num
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

def parse_author_names(author_text)
  plain_text(author_text)
    .split(/\s+and\s+/i)
    .map(&:strip)
    .reject(&:empty?)
    .map do |name|
      if name.include?(",")
        parts = name.split(",").map(&:strip).reject(&:empty?)
        if parts.length >= 2
          "#{parts[1..].join(' ')} #{parts[0]}".gsub(/\s+/, " ").strip
        else
          name.gsub(/\s+/, " ").strip
        end
      else
        name.gsub(/\s+/, " ").strip
      end
    end
end

def author_is_user?(author_name, user_profile)
  author_norm = normalize_name(author_name)
  return false if author_norm.empty? || user_profile[:full_norm].empty?
  return true if author_norm == user_profile[:full_norm]

  first_norm = user_profile[:first_norm]
  last_norm = user_profile[:last_norm]
  return false if first_norm.empty? || last_norm.empty?

  author_tokens = author_norm.split(" ")
  author_tokens.include?(first_norm) && author_tokens.include?(last_norm)
end

def format_authors(author_text, user_profile)
  names = parse_author_names(author_text)

  names.map do |name|
    escaped_name = latex_escape(name)
    if author_is_user?(name, user_profile)
      "\\textbf{#{escaped_name}}"
    else
      escaped_name
    end
  end.join(" and ")
end

def parse_publications(bib_content, user_profile)
  entries = split_bib_entries(bib_content)

  publications = entries.filter_map do |entry|
    match = entry.match(/\A@([A-Za-z]+)\s*\{\s*([^,]+)\s*,(.*)\}\s*\z/m)
    next unless match

    entry_type = match[1].downcase
    next unless %w[article inproceedings].include?(entry_type)

    citation_key = plain_text(match[2])
    fields = parse_fields(match[3])

    title = latex_escape(plain_text(fields["title"]))
    next if title.empty?

    year_text = plain_text(fields["year"])
    year_value = year_text[/\d{4}/] || year_text
    year_value = "0000" if year_value.to_s.empty?
    year_number = (year_text[/\d{4}/] || "0").to_i

    month_number = month_to_number(fields["month"])

    doi_url = normalize_doi_to_url(fields["doi"])

    author = format_authors(fields["author"], user_profile)
    next if author.empty?

    publication = {
      key: citation_key,
      type: entry_type,
      title: title,
      year: latex_escape(year_value),
      year_number: year_number,
      month_number: month_number,
      url: doi_url,
      author: author,
      keywords: entry_type == "article" ? "J" : "C"
    }

    if entry_type == "article"
      publication[:journal] = latex_escape(plain_text(fields["journal"]))
    else
      publication[:booktitle] = latex_escape(plain_text(fields["booktitle"]))
    end

    publication
  end

  publications.sort_by do |publication|
    [
      -publication[:year_number],
      -publication[:month_number],
      publication[:title].downcase
    ]
  end
end

def build_inline_ref_bib(publications)
  return "% No publications found from _papers.bib" if publications.empty?

  publications.map do |publication|
    lines = []
    lines << "@#{publication[:type]}{#{publication[:key]},"
    lines << "  title = {#{publication[:title]}},"

    if publication[:type] == "article"
      lines << "  journal = {#{publication[:journal]}}," unless publication[:journal].to_s.empty?
    else
      lines << "  booktitle = {#{publication[:booktitle]}}," unless publication[:booktitle].to_s.empty?
    end

    lines << "  year = {#{publication[:year]}},"
    lines << "  url = {#{publication[:url]}}," unless publication[:url].to_s.empty?
    lines << "  author = {#{publication[:author]}},"
    lines << "  keywords = {#{publication[:keywords]}}"
    lines << "}"
    lines.join("\n")
  end.join("\n\n")
end

def inject_ref_bib(template_content, bib_content)
  block = "\\begin{filecontents*}{ref.bib}\n#{bib_content}\n\\end{filecontents*}"
  pattern = /\\begin\{filecontents\*\}\{ref\.bib\}.*?\\end\{filecontents\*\}/m

  if template_content.match?(pattern)
    template_content.sub(pattern, block)
  else
    "#{block}\n\n#{template_content}"
  end
end

def render_template(template_content, replacements)
  rendered = template_content.dup

  replacements.each do |key, value|
    pattern = /\{\{\s*#{Regexp.escape(key)}\s*\}\}/
    rendered = rendered.gsub(pattern) { value }
  end

  rendered
end

def force_bibliography_order(template_content)
  # Keep entry order from generated ref.bib so year/month sort from parser is preserved.
  template_content.sub(/sorting\s*=\s*[^,\]]+/, "sorting=none")
end

unless File.file?(template_file)
  warn "Template file #{template_file} was not found."
  exit 1
end

config_data = {}
if (config_content = read_file_if_exists(config_file))
  parsed = YAML.safe_load(config_content, aliases: true)
  config_data = parsed.is_a?(Hash) ? parsed : {}
end

first_name = config_data["first_name"].to_s.strip
middle_name = config_data["middle_name"].to_s.strip
last_name = config_data["last_name"].to_s.strip
full_name = [first_name, middle_name, last_name].reject(&:empty?).join(" ")
full_name = "Your Name" if full_name.empty?

user_profile = {
  full_norm: normalize_name(full_name),
  first_norm: normalize_name(first_name),
  last_norm: normalize_name(last_name)
}

bib_content = read_file_if_exists(bib_file)
if bib_content.nil?
  warn "Bibliography file #{bib_file} was not found. Rendering template with an empty publication list."
  publications = []
else
  publications = parse_publications(bib_content, user_profile)
end

template_content = File.read(template_file)
inline_bib = build_inline_ref_bib(publications)
content = inject_ref_bib(template_content, inline_bib)
content = force_bibliography_order(content)

replacements = {
  "FULL_NAME" => latex_escape(full_name),
  "FIRST_NAME" => latex_escape(first_name),
  "MIDDLE_NAME" => latex_escape(middle_name),
  "LAST_NAME" => latex_escape(last_name),
  "EMAIL" => latex_escape(config_data["email"].to_s.strip),
  "DESCRIPTION" => latex_escape(plain_text(config_data["description"])),
  "SITE_URL" => latex_escape(config_data["url"].to_s.strip)
}

content = render_template(content, replacements)

FileUtils.mkdir_p(File.dirname(output_file))

if File.exist?(output_file) && File.read(output_file) == content
  puts "No changes detected for #{output_file}; rendered CV LaTeX is up to date."
  exit 0
end

journal_count = publications.count { |publication| publication[:type] == "article" }
conference_count = publications.count { |publication| publication[:type] == "inproceedings" }

File.write(output_file, content)
puts "Rendered #{output_file} from template #{template_file} with #{journal_count} journal and #{conference_count} conference publication(s)."
