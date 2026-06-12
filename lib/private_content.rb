# frozen_string_literal: true

# Resolves operator-specific content from the git-ignored private companion repo.
class PrivateContent
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
