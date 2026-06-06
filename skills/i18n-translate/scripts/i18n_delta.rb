#!/usr/bin/env ruby
# frozen_string_literal: true

# i18n delta finder.
#
# Compares the English source locale (config/locales/en.yml) against one or more
# target locales and reports the keys that are missing (the "delta") so they can
# be translated. Pure Ruby — no Rails boot, no gems beyond the stdlib.
#
# Usage:
#   ruby skills/i18n-translate/scripts/i18n_delta.rb              # report every locale
#   ruby skills/i18n-translate/scripts/i18n_delta.rb de           # report German only
#   ruby skills/i18n-translate/scripts/i18n_delta.rb --emit de    # YAML skeleton to translate
#   ruby skills/i18n-translate/scripts/i18n_delta.rb --all de     # include framework keys
#
# By default only *application* keys are compared; Rails framework keys (number.*,
# date.*, time.*, datetime.*, errors.*, support.*, activerecord.*) that ship only
# for English are ignored, because their German equivalents come from the locale
# file's hand-maintained framework block rather than the app's own copy.
#
# Exit status is non-zero when any target locale has a missing key, so the script
# doubles as a CI gate.

require "yaml"
require "set"

SOURCE_LOCALE = "en"
FRAMEWORK_ROOTS = %w[number date time datetime errors support activerecord helpers].freeze

def locales_dir
  File.expand_path("../../../config/locales", __dir__)
end

def load_locale(locale)
  path = File.join(locales_dir, "#{locale}.yml")
  abort "Missing locale file: #{path}" unless File.exist?(path)
  data = YAML.load_file(path) || {}
  data[locale] || {}
end

# Flattens a nested hash into "a.b.c" => value pairs.
def flatten_keys(hash, prefix = "")
  hash.each_with_object({}) do |(key, value), acc|
    full = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
    if value.is_a?(Hash)
      acc.merge!(flatten_keys(value, full))
    else
      acc[full] = value
    end
  end
end

def app_only(flat)
  flat.reject { |key, _| FRAMEWORK_ROOTS.include?(key.split(".").first) }
end

# Rebuilds a nested hash from "a.b.c" => value pairs (for --emit output).
def nest(flat)
  root = {}
  flat.each do |dotted, value|
    parts = dotted.split(".")
    leaf = parts.pop
    cursor = parts.reduce(root) { |node, part| node[part] ||= {} }
    cursor[leaf] = value
  end
  root
end

def available_target_locales
  Dir[File.join(locales_dir, "*.yml")]
    .map { |f| File.basename(f, ".yml") }
    .reject { |l| l == SOURCE_LOCALE }
    .sort
end

# --- argument parsing -------------------------------------------------------
args = ARGV.dup
emit = args.delete("--emit")
include_framework = args.delete("--all")
targets = args.empty? ? available_target_locales : args

source = load_locale(SOURCE_LOCALE)
source_flat = flatten_keys(source)
source_flat = app_only(source_flat) unless include_framework

exit_code = 0

targets.each do |locale|
  target_flat = flatten_keys(load_locale(locale))
  missing = source_flat.reject { |key, _| target_flat.key?(key) }

  if emit
    next if missing.empty?

    puts "# Missing keys for '#{locale}' (English values shown — translate in place):"
    puts({ locale => nest(missing) }.to_yaml)
    exit_code = 1
    next
  end

  if missing.empty?
    puts "✓ #{locale}: complete (no missing keys)"
  else
    exit_code = 1
    puts "✗ #{locale}: #{missing.size} missing key(s)"
    missing.keys.sort.each { |key| puts "    #{key}" }
  end
end

exit exit_code
