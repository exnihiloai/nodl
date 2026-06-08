# Resolves operator-specific legal pages from the git-ignored private/ directory.
# OSS deployments without private/legal/ simply omit routes from the footer and
# return 404 for direct requests.
#
# Content may be authored either as Markdown (`*.md`, rendered to HTML at request
# time) or as ERB/HTML (`*.html.erb`). Filenames are matched against the slug
# itself and, where the canonical document is named differently, an aliased
# basename (e.g. the `privacy` slug resolves `data-protection`).
#
# Language is selected from the visitor's locale. German is the authoritative
# language: a missing translation falls back to the German version rather than
# 404ing, so visitors always see a valid document. Two filename schemes are
# supported per language: a `-DE`/`-EN` suffix (current authoring convention)
# and a legacy `.de`/`.en` dotted infix (still used by the imprint).
class LegalPage
  SLUGS = %w[imprint privacy terms ai_transparency subprocessors security].freeze

  # Core documents shown directly in the site footer. The remaining, more
  # detailed compliance documents are surfaced contextually from these pages via
  # RELATED rather than crowding the footer.
  FOOTER_SLUGS = %w[imprint privacy terms].freeze

  # Per-page "related documents" navigation: each legal page links to the other
  # documents that are contextually relevant to it. Links only render for
  # documents that actually exist.
  RELATED = {
    "imprint" => %w[privacy terms],
    "privacy" => %w[terms ai_transparency security subprocessors],
    "terms" => %w[privacy ai_transparency],
    "ai_transparency" => %w[privacy terms],
    "security" => %w[privacy subprocessors],
    "subprocessors" => %w[privacy security]
  }.freeze

  # Maps a slug to the canonical document basename used in private/legal/.
  # The slug itself is always tried as a fallback basename too, so operators may
  # name files after either the slug or the document.
  FILE_BASES = {
    "privacy" => "data-protection",
    "terms" => "terms-of-service",
    "ai_transparency" => "ai-transparency"
  }.freeze

  # German is the legally authoritative version and is always present; it is the
  # final language fallback and the canonical source for consent versioning.
  AUTHORITATIVE_LOCALE = :de

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
    # Derived from the "**Stand:** <date>" line of the authoritative (German)
    # version so the identifier is stable across languages: bumping that date on
    # a legal update registers as a new version requiring fresh consent.
    def version(slug, locale: AUTHORITATIVE_LOCALE)
      path = resolve(slug, locale: locale)
      return nil unless path

      match = path.read.match(STAND_PATTERN)
      match && match[1].strip
    end

    private

    def candidate_paths(slug, locale)
      bases = [ FILE_BASES[slug.to_s], slug.to_s ].compact.uniq

      bases.flat_map do |base|
        filenames(base, locale).map { |name| root.join(name) }
      end
    end

    # Filenames for one basename in priority order: the visitor's language first
    # (suffix scheme, then legacy dotted scheme), then the authoritative German
    # language, then a language-agnostic generic file.
    def filenames(base, locale)
      languages = [ locale.to_s, AUTHORITATIVE_LOCALE.to_s ].uniq

      names = languages.flat_map do |lang|
        EXTENSIONS.flat_map do |ext|
          [ "#{base}-#{lang.upcase}.#{ext}", "#{base}.#{lang}.#{ext}" ]
        end
      end

      names + EXTENSIONS.map { |ext| "#{base}.#{ext}" }
    end
  end
end
