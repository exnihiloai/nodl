require "test_helper"

class SitemapIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @legal_root = Rails.root.join("tmp/sitemap_integration_test/#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@legal_root)
    LegalPage.root = @legal_root
  end

  teardown do
    LegalPage.reset_root!
    FileUtils.rm_rf(@legal_root)
  end

  test "sitemap is served as xml with public marketing urls" do
    get sitemap_path(format: :xml)

    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
    assert_includes response.body, "<loc>http://www.example.com/</loc>"
    assert_includes response.body, "<loc>http://www.example.com/about</loc>"
    assert_includes response.body, "<loc>http://www.example.com/register</loc>"
  end

  test "sitemap includes legal pages when private templates exist" do
    write_legal_page("terms", :en, "<section><h1>Terms</h1></section>")

    get sitemap_path(format: :xml)

    assert_response :success
    assert_includes response.body, "<loc>http://www.example.com/agb</loc>"
    assert_not_includes response.body, "<loc>http://www.example.com/datenschutz</loc>"
  end

  test "robots.txt references the sitemap" do
    get robots_path

    assert_response :success
    assert_equal "text/plain; charset=utf-8", response.content_type
    assert_includes response.body, "Sitemap: http://www.example.com/sitemap.xml"
    assert_includes response.body, "Allow: /"
  end

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
