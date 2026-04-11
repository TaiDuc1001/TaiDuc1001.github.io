#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'time'
require 'uri'

repositories_page = ARGV[0] || '_pages/repositories.md'
output_file = ARGV[1] || '_data/github_metadata.json'

unless File.exist?(repositories_page)
  warn "Repositories page not found: #{repositories_page}"
  exit 1
end

content = File.read(repositories_page)
usernames = content.scan(/repo_user\.liquid username='([^']+)'/).flatten.uniq
repositories = content.scan(/repo\.liquid repository='([^']+)'/).flatten.uniq

existing = if File.exist?(output_file)
  JSON.parse(File.read(output_file))
else
  {}
end

cached_users = (existing['users'] || []).each_with_object({}) { |entry, acc| acc[entry['login']] = entry if entry['login'] }
cached_repositories = (existing['repositories'] || []).each_with_object({}) { |entry, acc| acc[entry['full_name']] = entry if entry['full_name'] }

token = ENV['GITHUB_TOKEN'].to_s.strip
token = ENV['GH_TOKEN'].to_s.strip if token.empty?

headers = {
  'Accept' => 'application/vnd.github+json',
  'User-Agent' => 'TaiDuc1001-site-build'
}
headers['Authorization'] = "Bearer #{token}" unless token.empty?

def fetch_json(url, headers)
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }
    http.request(request)
  end

  return [nil, response] unless response.is_a?(Net::HTTPSuccess)

  [JSON.parse(response.body), response]
rescue StandardError => e
  warn "Request failed for #{url}: #{e.message}"
  [nil, nil]
end

users = usernames.map do |username|
  data, response = fetch_json("https://api.github.com/users/#{username}", headers)
  if data
    {
      'login' => username,
      'name' => data['name'],
      'bio' => data['bio'],
      'company' => data['company'],
      'followers' => data['followers'],
      'public_repos' => data['public_repos'],
      'html_url' => data['html_url'],
      'avatar_url' => data['avatar_url']
    }
  else
    warn "Falling back to cached user metadata for #{username}." if cached_users.key?(username)
    cached_users[username] || {
      'login' => username,
      'html_url' => "https://github.com/#{username}",
      'avatar_url' => "https://github.com/#{username}.png?size=160",
      'error' => response&.code || 'unavailable'
    }
  end
end

repos = repositories.map do |full_name|
  data, response = fetch_json("https://api.github.com/repos/#{full_name}", headers)
  if data
    {
      'full_name' => full_name,
      'name' => data['name'],
      'owner' => data.dig('owner', 'login'),
      'description' => data['description'],
      'language' => data['language'],
      'stargazers_count' => data['stargazers_count'],
      'forks_count' => data['forks_count'],
      'html_url' => data['html_url']
    }
  else
    warn "Falling back to cached repo metadata for #{full_name}." if cached_repositories.key?(full_name)
    cached_repositories[full_name] || {
      'full_name' => full_name,
      'html_url' => "https://github.com/#{full_name}",
      'error' => response&.code || 'unavailable'
    }
  end
end

generated = {
  'generated_at' => Time.now.utc.iso8601,
  'users' => users,
  'repositories' => repos
}

json = JSON.pretty_generate(generated) + "\n"

if File.exist?(output_file) && File.read(output_file) == json
  puts "No changes detected for #{output_file}; GitHub metadata is up to date."
  exit 0
end

File.write(output_file, json)
puts "Generated #{output_file} with #{users.length} user(s) and #{repos.length} repository record(s)."
