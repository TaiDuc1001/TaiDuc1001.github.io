#!/usr/bin/env ruby

require 'set'

template_file = ARGV[0] || '_pages/repositories.template.md'
output_file = ARGV[1] || '_pages/repositories.md'
bib_file = ARGV[2] || '_bibliography/_papers.bib'

unless File.exist?(template_file)
  warn "Template not found: #{template_file}"
  exit 1
end

unless File.exist?(bib_file)
  warn "BibTeX file not found: #{bib_file}"
  exit 1
end

template = File.read(template_file)
bib_content = File.read(bib_file)

code_values = bib_content.scan(/\bcode\s*=\s*(?:\{([^}]*)\}|"([^"]*)")/i).map { |a, b| a || b }.compact

repos = Set.new

code_values.each do |value|
  value.scan(%r{https?://github\.com/([^/\s]+)/([^/\s#?]+)}i) do |owner, repo|
    next if owner.nil? || repo.nil?

    normalized_repo = repo.sub(/\.git\z/i, '')
    next if normalized_repo.empty?

    repos << "#{owner}/#{normalized_repo}"
  end
end

sorted_repos = repos.to_a.sort_by(&:downcase)
sorted_users = sorted_repos.map { |repo| repo.split('/').first }.uniq.sort_by(&:downcase)

users_markup = if sorted_users.empty?
  "  <p>No GitHub users found from <code>code</code> fields in <code>_papers.bib</code>.</p>"
else
  sorted_users.map { |user| "  {% include repository/repo_user.liquid username='#{user}' %}" }.join("\n")
end

repos_markup = if sorted_repos.empty?
  "  <p>No GitHub repositories found from <code>code</code> fields in <code>_papers.bib</code>.</p>"
else
  sorted_repos.map { |repo| "  {% include repository/repo.liquid repository='#{repo}' %}" }.join("\n")
end

rendered = template
  .gsub('{{AUTO_GITHUB_USERS}}', users_markup)
  .gsub('{{AUTO_GITHUB_REPOS}}', repos_markup)
  .gsub(/^published:\s*false\s*$/i, '')
  .gsub(/\n{3,}/, "\n\n")

if File.exist?(output_file) && File.read(output_file) == rendered
  puts "No changes detected for #{output_file}; repositories page is up to date."
  exit 0
end

File.write(output_file, rendered)
puts "Generated #{output_file} with #{sorted_users.length} GitHub user(s) and #{sorted_repos.length} repository card(s)."
