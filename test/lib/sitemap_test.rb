require "test_helper"

class SitemapTest < ActiveSupport::TestCase
  setup do
    @legal_root = Rails.root.join("tmp/sitemap_test/#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@legal_root)
    LegalPage.root = @legal_root
  end

  teardown do
    LegalPage.reset_root!
    FileUtils.rm_rf(@legal_root)
  end

  test "includes marketing pages" do
    entries = Sitemap.entries(base_url: "https://example.com", url_helpers: Rails.application.routes.url_helpers)

    locs = entries.map(&:loc)
    assert_includes locs, "https://example.com/"
    assert_includes locs, "https://example.com/about"
    assert_includes locs, "https://example.com/try-now"
    assert_includes locs, "https://example.com/login"
    assert_includes locs, "https://example.com/register"
  end

  test "includes legal pages only when private templates exist" do
    write_legal_page("privacy", :en, "<section><h1>Privacy</h1></section>")

    entries = Sitemap.entries(base_url: "https://example.com", url_helpers: Rails.application.routes.url_helpers)
    locs = entries.map(&:loc)

    assert_includes locs, "https://example.com/datenschutz"
    assert_not_includes locs, "https://example.com/agb"
    assert_not_includes locs, "https://example.com/impressum"
  end

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
