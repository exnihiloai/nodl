# Builds the list of public, indexable URLs for /sitemap.xml.
class Sitemap
  Entry = Data.define(:loc, :changefreq, :priority)

  PUBLIC_ENTRIES = [
    { path: :root_path, changefreq: "weekly", priority: "1.0" },
    { path: :login_path, changefreq: "monthly", priority: "0.5" },
    { path: :register_path, changefreq: "monthly", priority: "0.7" }
  ].freeze

  MARKETING_ENTRIES = [
    { path: :about_path, changefreq: "monthly", priority: "0.8" },
    { path: :for_doctors_path, changefreq: "monthly", priority: "0.8" },
    { path: :for_dentists_path, changefreq: "monthly", priority: "0.8" },
    { path: :for_overthinkers_path, changefreq: "monthly", priority: "0.8" },
    { path: :for_journaling_path, changefreq: "monthly", priority: "0.8" },
    { path: :for_interviews_path, changefreq: "monthly", priority: "0.8" },
    { path: :for_coaches_path, changefreq: "monthly", priority: "0.8" },
    { path: :try_now_path, changefreq: "monthly", priority: "0.8" }
  ].freeze

  LEGAL_ENTRIES = {
    "imprint" => :imprint_path,
    "privacy" => :privacy_path,
    "terms" => :terms_path
  }.freeze

  class << self
    def entries(base_url:, url_helpers:)
      public_entries(base_url:, url_helpers:) + marketing_entries(base_url:, url_helpers:) + legal_entries(base_url:, url_helpers:)
    end

    private

    def public_entries(base_url:, url_helpers:)
      PUBLIC_ENTRIES.map { |entry| build_entry(entry, base_url:, url_helpers:) }
    end

    def marketing_entries(base_url:, url_helpers:)
      MARKETING_ENTRIES.filter_map do |entry|
        next unless PrivateContent.marketing_page?(entry.fetch(:path).to_s.delete_suffix("_path").to_sym)

        build_entry(entry, base_url:, url_helpers:)
      end
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
