# Derives the third-party software inventory from the *live* dependency tree.
#
# This is the source of truth that backs config/third_party_licenses.yml:
#   - `bin/rails licenses:generate` calls #build and writes the YAML.
#   - The drift guard (test/lib/third_party_license_inventory_test.rb) calls
#     #build and fails the gate if the committed YAML no longer matches.
#
# Gem data comes from Bundler's locked `default` group (so versions track
# Gemfile.lock automatically). Non-gem assets are merged from
# config/third_party_assets.yml.
class ThirdPartyLicenseInventory
  ASSETS_CONFIG = Rails.root.join("config", "third_party_assets.yml")
  DAISYUI_CSS = Rails.root.join("app", "assets", "stylesheets", "daisyui.css")
  TEXTS_DIR = Rails.root.join("config", "third_party_licenses")

  # Raw gemspec license string => license-family id used for grouping.
  FAMILIES = {
    "MIT" => "mit",
    "MIT/BSD-2-Clause" => "mit",
    "MIT/Apache-2.0" => "mit",
    "" => "mit", # ruby-rc4: undeclared in its gemspec; MIT upstream.
    "Apache-2.0" => "apache-2.0",
    "BSD-2-Clause" => "bsd-2-clause",
    "BSD-3-Clause" => "bsd-3-clause",
    "Ruby" => "ruby",
    "Ruby/BSD-2-Clause" => "ruby",
    "MPL-2.0" => "mpl-2.0",
    "Nonstandard/GPL-2.0-only/GPL-3.0-only" => "prawn"
  }.freeze

  # Display name + canonical license text file, in render order. Every family
  # id referenced by FAMILIES or the assets file must appear here.
  GROUP_META = [
    [ "mit",          "MIT License",                          "mit.txt" ],
    [ "bsd-2-clause", "BSD 2-Clause License",                 "bsd-2-clause.txt" ],
    [ "bsd-3-clause", "BSD 3-Clause License",                 "bsd-3-clause.txt" ],
    [ "isc",          "ISC License",                          "isc.txt" ],
    [ "apache-2.0",   "Apache License 2.0",                   "apache-2.0.txt" ],
    [ "mpl-2.0",      "Mozilla Public License 2.0",           "mpl-2.0.txt" ],
    [ "ruby",         "Ruby License",                         "ruby.txt" ],
    [ "ofl-1.1",      "SIL Open Font License 1.1",            "ofl-1.1.txt" ],
    [ "prawn",        "Prawn License (Ruby / GPLv2 / GPLv3)", "prawn.txt" ]
  ].freeze

  # Hand-corrected notices where a license file leads with boilerplate instead
  # of a clean copyright line. Revisit when bumping these gems.
  OVERRIDES = {
    "ansi" => "Copyright (c) Rubyworks",
    "hashery" => "Copyright (c) Rubyworks",
    "nokogiri" => "Copyright (c) Mike Dalessio, Aaron Patterson, and contributors",
    "msgpack" => "Copyright (c) Sadayuki Furuhashi",
    "oga" => "Copyright (c) Yorick Peterse",
    "ruby-ll" => "Copyright (c) Yorick Peterse",
    "google-protobuf" => "Copyright (c) 2008 Google Inc.",
    "googleapis-common-protos-types" => "Copyright (c) Google LLC",
    "minitest" => "Copyright (c) Ryan Davis, seattle.rb",
    "net-imap" => "Copyright (c) Yukihiro Matsumoto and contributors"
  }.freeze

  OTEL_COPYRIGHT = "Copyright The OpenTelemetry Authors".freeze
  SOCKETRY = %w[async async-http async-pool async-websocket console metrics traces
    io-endpoint io-event io-stream fiber-annotation fiber-local fiber-storage
    protocol-hpack protocol-http protocol-http1 protocol-http2 protocol-rack
    protocol-url protocol-websocket].freeze

  LICENSE_FILE_GLOB =
    "{LICENSE,LICENCE,COPYING,MIT-LICENSE,LICENSE.txt,LICENSE.md,LICENSE-MIT,COPYRIGHT}*".freeze

  # Raised when a dependency declares a license we have not mapped to a family.
  class UnmappedLicenseError < StandardError; end

  def self.build
    new.build
  end

  # Returns the inventory as a plain Hash matching the YAML structure:
  #   { "groups" => [ { "id", "name", "body_file", "components" => [...] } ] }
  def build
    assets = load_assets
    groups = GROUP_META.map do |id, name, body_file|
      components = (gem_components[id] || []) + (assets[id] || [])
      components = components.sort_by { |c| c["name"].downcase }
      { "id" => id, "name" => name, "body_file" => body_file, "components" => components }
    end
    { "groups" => groups }
  end

  private

  def gem_components
    @gem_components ||= begin
      grouped = Hash.new { |h, k| h[k] = [] }
      runtime_specs.each do |spec|
        family = FAMILIES[license_string(spec)]
        unless family
          raise UnmappedLicenseError,
            "#{spec.name} declares license #{license_string(spec).inspect}, " \
            "which is not mapped in ThirdPartyLicenseInventory::FAMILIES"
        end
        grouped[family] << {
          "name" => spec.name,
          "version" => spec.version.to_s,
          "copyright" => notice_for(spec),
          "url" => presence(spec.homepage)
        }
      end
      grouped
    end
  end

  # Gems shipped in production: Bundler's locked `default` group.
  def runtime_specs
    runtime = Bundler.definition.specs_for([ :default ]).map(&:name).to_set
    Bundler.load.specs.to_a.uniq(&:name).select { |s| runtime.include?(s.name) }
  end

  def license_string(spec)
    licenses = Array(spec.licenses).reject(&:blank?)
    licenses.empty? ? "" : licenses.join("/")
  end

  def notice_for(spec)
    name = spec.name
    return OVERRIDES[name] if OVERRIDES.key?(name)
    return OTEL_COPYRIGHT if name.start_with?("opentelemetry-")
    return "Copyright (c) Samuel Williams and contributors" if SOCKETRY.include?(name)

    extracted = copyright_from_files(spec.full_gem_path)
    return extracted if extracted

    authors = Array(spec.authors).join(", ").strip
    authors.empty? ? nil : "Copyright (c) #{authors}"
  end

  def copyright_from_files(dir)
    license_files(dir).each do |file|
      File.foreach(file) do |line|
        candidate = line.strip
        next unless candidate =~ /\Acopyright/i || candidate =~ /\A\(c\)/i
        next if boilerplate?(candidate)
        next if candidate.length > 120

        return candidate
      end
    end
    nil
  end

  # License files in deterministic preference order: a real LICENSE wins over a
  # COPYING (often a copyleft clause list) or a generic COPYRIGHT file, so the
  # extracted notice is stable across machines and glob orderings.
  def license_files(dir)
    Dir.glob(File.join(dir, LICENSE_FILE_GLOB), File::FNM_CASEFOLD)
      .select { |f| File.file?(f) }
      .uniq
      .sort_by { |f| [ file_rank(File.basename(f)), File.basename(f) ] }
  end

  def file_rank(basename)
    case basename
    when /\Alicen[cs]e/i, /\Amit-license/i then 0
    when /\Acopying/i then 1
    when /\Acopyright/i then 2
    else 3
    end
  end

  def boilerplate?(line)
    line =~ /licensor|shall mean|doctrines|provided by the copyright|reproduce the above|copyright (notice|owner|holder|of)\b/i
  end

  def load_assets
    data = YAML.load_file(ASSETS_CONFIG)
    data.transform_values do |components|
      components.map { |component| normalize_asset(component) }
    end
  end

  def normalize_asset(component)
    {
      "name" => component.fetch("name"),
      "version" => asset_version(component),
      "copyright" => component["copyright"],
      "url" => component["url"]
    }
  end

  def asset_version(component)
    case component["version_source"]
    when "daisyui_css" then daisyui_version
    when nil then component["version"]
    else
      raise "Unknown version_source #{component["version_source"].inspect} " \
        "for asset #{component["name"].inspect} in #{ASSETS_CONFIG}"
    end
  end

  # Reads DaisyUI's own banner (e.g. "daisyUI 5.0.33") from the vendored CSS so
  # the version tracks the asset instead of a hand-edited string.
  def daisyui_version
    banner = File.foreach(DAISYUI_CSS).find { |line| line =~ /daisyUI\s+\d+\.\d+\.\d+/ }
    raise "Could not detect DaisyUI version in #{DAISYUI_CSS}" unless banner

    banner[/daisyUI\s+v?(\d+\.\d+\.\d+)/, 1]
  end

  def presence(value)
    value.to_s.empty? ? nil : value
  end
end
