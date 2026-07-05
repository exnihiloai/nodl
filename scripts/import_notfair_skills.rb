#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require "yaml"

SOURCE_ROOT = Pathname(ENV.fetch("NOTFAIR_SOURCE", "/Users/sebastianbeyer/Downloads/NotFair-main")).expand_path
DEST_ROOT = Pathname(__dir__).join("..", "skills").expand_path
PLUGIN_JSON = SOURCE_ROOT.join(".claude-plugin", "plugin.json")
VERSION_FILE = SOURCE_ROOT.join("VERSION")

def parse_skill_md(path)
  content = path.read
  raise "No frontmatter in #{path}" unless content.start_with?("---\n")

  rest = content[4..]
  end_idx = rest.index("\n---\n")
  raise "Unclosed frontmatter in #{path}" unless end_idx

  frontmatter = YAML.safe_load(rest[0...end_idx], permitted_classes: [], aliases: true) || {}
  body = rest[(end_idx + 5)..].lstrip
  [frontmatter, body]
end

def extract_steps(body, frontmatter)
  steps = []

  Array(frontmatter["triggers"]).first(5).each do |trigger|
    steps << "Activate when the user mentions #{trigger} or related NotFair workflows."
  end

  if body =~ /^## (?:How to work|Workflow|Setup)\s*\n(.*?)(?=^## |\z)/m
    section = Regexp.last_match(1)
    section.scan(/^\d+\.\s+\*\*(.+?)\*\*/).each { |match| steps << match[0].strip }
    section.scan(/^\d+\.\s+(.+)$/).each { |match| steps << match[0].strip }
  end

  if steps.empty?
    body.scan(/^## (.+)$/).each do |match|
      title = match[0].strip
      next if title.match?(/\A(Setup|Requirements|Out of scope|Tool surface)\z/i)

      steps << "Follow the #{title} section in skill.md."
      break if steps.size >= 5
    end
  end

  steps = steps.map { |step| step.gsub(/\s+/, " ").strip }.reject(&:empty?).uniq.first(8)
  steps = ["Read skill.md and execute the documented NotFair workflow."] if steps.empty?
  steps
end

def display_name(body, skill_id)
  first_line = body.lines.first.to_s.strip
  if first_line.start_with?("#")
    title = first_line.sub(/\A#+\s*/, "").strip
    title = title.split(/\s+[—–-]\s+/).first.to_s.strip
    return title unless title.empty?
  end

  skill_id.split("-").map(&:capitalize).join(" ")
end

def copy_tree(source, destination)
  return unless source.directory?

  FileUtils.mkdir_p(destination.dirname)
  FileUtils.rm_rf(destination) if destination.exist?
  FileUtils.cp_r(source, destination)
end

raise "NotFair source not found: #{SOURCE_ROOT}" unless SOURCE_ROOT.directory?
raise "Missing plugin.json: #{PLUGIN_JSON}" unless PLUGIN_JSON.file?

plugin = JSON.parse(PLUGIN_JSON.read)
skill_paths = Array(plugin["skills"]).map { |path| path.to_s.delete_prefix("./") }
version = VERSION_FILE.file? ? VERSION_FILE.read.strip : "1.0.0"

imported = 0
skill_paths.each do |relative_path|
  source_dir = SOURCE_ROOT.join(relative_path)
  skill_md_path = source_dir.join("SKILL.md")
  raise "Missing SKILL.md for #{relative_path}" unless skill_md_path.file?

  frontmatter, body = parse_skill_md(skill_md_path)
  skill_id = (frontmatter["name"] || Pathname(relative_path).basename.to_s).to_s.strip
  summary = frontmatter["description"].to_s.strip
  summary = frontmatter["short_description"].to_s.strip if summary.empty?
  raise "No description for #{relative_path}" if summary.empty?

  dest_dir = DEST_ROOT.join(relative_path)
  FileUtils.mkdir_p(dest_dir)

  manifest = {
    "id" => skill_id,
    "name" => display_name(body, skill_id),
    "version" => version,
    "entrypoints" => [],
    "instructions" => {
      "summary" => summary,
      "steps" => extract_steps(body, frontmatter)
    },
    "inputs" => [],
    "outputs" => [],
    "compat" => {
      "claude_agent" => true,
      "codex_skill" => true
    }
  }

  dest_dir.join("manifest.yml").write(YAML.dump(manifest))
  dest_dir.join("skill.md").write(body)

  %w[references scripts evals].each do |subdir|
    copy_tree(source_dir.join(subdir), dest_dir.join(subdir))
  end

  imported += 1
  puts "Imported #{relative_path} (#{skill_id})"
end

%w[google-ads/shared meta-ads/shared].each do |shared_path|
  source = SOURCE_ROOT.join(shared_path)
  next unless source.directory?

  destination = DEST_ROOT.join(shared_path)
  copy_tree(source, destination)
  puts "Copied shared assets: #{shared_path}"
end

puts "Done. Imported #{imported} NotFair skill(s) into #{DEST_ROOT}"
