# Resolves operator-specific legal pages from the git-ignored private/ directory.
# OSS deployments without private/legal/ simply omit routes from the footer and
# return 404 for direct requests.
class LegalPage
  SLUGS = %w[imprint privacy terms].freeze
  DEFAULT_ROOT = Rails.root.join("private/legal")

  class << self
    attr_writer :root

    def root
      @root ||= DEFAULT_ROOT
    end

    def reset_root!
      @root = DEFAULT_ROOT
    end

    def resolve(slug, locale: I18n.locale)
      localized = root.join("#{slug}.#{locale}.html.erb")
      return localized if localized.file?

      fallback = root.join("#{slug}.#{I18n.default_locale}.html.erb")
      return fallback if fallback.file?

      generic = root.join("#{slug}.html.erb")
      generic if generic.file?
    end

    def exists?(slug)
      SLUGS.include?(slug.to_s) && I18n.available_locales.any? { |locale| resolve(slug, locale: locale).present? }
    end
  end
end
