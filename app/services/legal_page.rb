# Resolves operator-specific legal pages from the git-ignored private/ directory.
# OSS deployments without private/legal/ simply omit routes from the footer and
# return 404 for direct requests.
#
# Content may be authored either as Markdown (`*.md`, rendered to HTML at request
# time) or as ERB/HTML (`*.html.erb`). Filenames are matched against the slug
# itself and, where the canonical document is named differently, an aliased
# basename (e.g. the `privacy` slug resolves `data-protection.md`).
class LegalPage
  SLUGS = %w[imprint privacy terms ai_transparency].freeze

  # Maps a slug to the canonical document basename used in private/legal/.
  # The slug itself is always tried as a fallback basename too, so operators may
  # name files after either the slug or the document.
  FILE_BASES = {
    "privacy" => "data-protection",
    "terms" => "terms-of-service",
    "ai_transparency" => "ai-transparency"
  }.freeze

  EXTENSIONS = %w[md html.erb].freeze
  STAND_PATTERN = /\*\*Stand:\*\*\s*(.+?)\s*$/i

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
      candidate_paths(slug, locale).find(&:file?)
    end

    def exists?(slug)
      SLUGS.include?(slug.to_s) && I18n.available_locales.any? { |locale| resolve(slug, locale: locale).present? }
    end

    def markdown?(path)
      path.to_s.end_with?(".md")
    end

    # Version identifier for a document, used to record and compare consent.
    # Derived from the "**Stand:** <date>" line so that bumping the date on a
    # legal update naturally registers as a new version requiring fresh consent.
    def version(slug, locale: I18n.locale)
      path = resolve(slug, locale: locale)
      return nil unless path

      match = path.read.match(STAND_PATTERN)
      match && match[1].strip
    end

    private

    def candidate_paths(slug, locale)
      bases = [ FILE_BASES[slug.to_s], slug.to_s ].compact.uniq
      variants = [ "#{locale}.%s", "#{I18n.default_locale}.%s", "%s" ]

      bases.flat_map do |base|
        variants.flat_map do |variant|
          EXTENSIONS.map { |ext| root.join("#{base}.#{format(variant, ext)}") }
        end
      end
    end
  end
end
