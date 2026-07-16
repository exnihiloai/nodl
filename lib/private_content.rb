# frozen_string_literal: true

# Resolves operator-specific content from the git-ignored private companion repo.
class PrivateContent
  CONTENT_SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  # Listing metadata for one operator article, parsed from its template.
  ContentPage = Data.define(:slug, :title, :description)

  # Articles declare their metadata inline (`content_for :title` + meta
  # description); the hub index reads it back out of the template source so
  # there is no separate manifest to keep in sync.
  CONTENT_TITLE_PATTERN = /content_for\s+:title,\s*"([^"]+)"/
  CONTENT_DESCRIPTION_PATTERN = /<meta\s+name="description"\s+content="([^"]+)"/
  CONTENT_TITLE_BRAND_SUFFIX = /\s*[-–—]\s*Nodl\z/

  MARKETING_PAGES = {
    about: "pages/about",
    for_doctors: "pages/for_doctors",
    for_dentists: "pages/for_dentists",
    for_overthinkers: "pages/for_overthinkers",
    for_journaling: "pages/for_journaling",
    for_interviews: "pages/for_interviews",
    for_coaches: "pages/for_coaches",
    try_now: "pages/try_now"
  }.freeze

  class << self
    attr_writer :root, :view_root, :locale_root

    def root
      @root ||= Rails.root.join("private")
    end

    def view_root
      @view_root ||= root.join("views")
    end

    def locale_root
      @locale_root ||= root.join("locales")
    end

    def marketing?
      template?("pages/home")
    end

    def marketing_page?(name)
      template = MARKETING_PAGES.fetch(name)

      template?(template)
    end

    # Operator articles/guides live at private/views/content/<locale>/<slug>.html.erb
    # and are served by ContentPagesController under /artikel (de) and /articles (en).
    def content_page?(locale, slug)
      return false unless slug.to_s.match?(CONTENT_SLUG_FORMAT)

      template?("content/#{locale}/#{slug}")
    end

    def content_slugs(locale)
      dir = view_root.join("content", locale.to_s)
      return [] unless dir.directory?

      Dir[dir.join("*.html.erb").to_s]
        .map { |file| File.basename(file, ".html.erb") }
        .grep(CONTENT_SLUG_FORMAT)
        .sort
    end

    def content_pages(locale)
      content_slugs(locale).map do |slug|
        source = view_root.join("content", locale.to_s, "#{slug}.html.erb").read
        title = source[CONTENT_TITLE_PATTERN, 1]&.sub(CONTENT_TITLE_BRAND_SUFFIX, "")

        ContentPage.new(
          slug:,
          title: title.presence || slug.tr("-", " ").upcase_first,
          description: source[CONTENT_DESCRIPTION_PATTERN, 1]
        )
      end
    end

    def locale_paths
      return [] unless locale_root.directory?

      Dir[locale_root.join("**", "*.{rb,yml}")]
    end

    def reset!
      @root = nil
      @view_root = nil
      @locale_root = nil
    end

    private

    def template?(logical_path)
      return false unless view_root.directory?

      %w[html.erb erb].any? { |extension| view_root.join("#{logical_path}.#{extension}").file? }
    end
  end
end
