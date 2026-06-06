# Builds the list of public, indexable URLs for /sitemap.xml.
class Sitemap
  Entry = Data.define(:loc, :changefreq, :priority)

  MARKETING_ENTRIES = [
    { path: :root_path, changefreq: "weekly", priority: "1.0" },
    { path: :about_path, changefreq: "monthly", priority: "0.8" },
    { path: :try_now_path, changefreq: "monthly", priority: "0.8" },
    { path: :login_path, changefreq: "monthly", priority: "0.5" },
    { path: :register_path, changefreq: "monthly", priority: "0.7" }
  ].freeze

  LEGAL_ENTRIES = {
    "imprint" => :imprint_path,
    "privacy" => :privacy_path,
    "terms" => :terms_path
  }.freeze

  class << self
    def entries(base_url:, url_helpers:)
      marketing_entries(base_url:, url_helpers:) + legal_entries(base_url:, url_helpers:)
    end

    private

    def marketing_entries(base_url:, url_helpers:)
      MARKETING_ENTRIES.map { |entry| build_entry(entry, base_url:, url_helpers:) }
    end

    def legal_entries(base_url:, url_helpers:)
      LEGAL_ENTRIES.filter_map do |slug, path_helper|
        next unless LegalPage.exists?(slug)

        build_entry({ path: path_helper, changefreq: "yearly", priority: "0.3" }, base_url:, url_helpers:)
      end
    end

    def build_entry(entry, base_url:, url_helpers:)
      path = url_helpers.public_send(entry.fetch(:path))
      Entry.new(
        loc: "#{base_url.chomp("/")}#{path}",
        changefreq: entry.fetch(:changefreq),
        priority: entry.fetch(:priority)
      )
    end
  end
end
