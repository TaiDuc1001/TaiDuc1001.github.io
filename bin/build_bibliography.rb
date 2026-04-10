#!/usr/bin/env ruby

require 'fileutils'

source_dir = ARGV[0] || '_bibliography/papers'
output_file = ARGV[1] || '_bibliography/_papers.bib'

source_files = Dir.glob(File.join(source_dir, '**', '*.bib')).sort

if source_files.empty?
  warn "No BibTeX source files found in #{source_dir}"
  exit 1
end

FileUtils.mkdir_p(File.dirname(output_file))

generated = []
generated << "% This file is generated automatically. Do not edit directly."
generated << "% Source directory: #{source_dir}"
generated << ''

source_files.each do |source_file|
  generated << '% -----------------------------------------------------------------------------'
  generated << "% Source: #{source_file}"
  generated << '% -----------------------------------------------------------------------------'
  generated << ''
  generated << File.read(source_file).strip
  generated << ''
end

content = generated.join("\n").rstrip + "\n"

if File.exist?(output_file) && File.read(output_file) == content
  puts "No changes detected for #{output_file}; bibliography is up to date."
  exit 0
end

File.write(output_file, content)
puts "Generated #{output_file} from #{source_files.length} BibTeX file(s)."