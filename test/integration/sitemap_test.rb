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
    Dir.mktmpdir do |private_views|
      with_private_view_root(private_views) do
        get sitemap_path(format: :xml)

        assert_response :success
        assert_equal "application/xml; charset=utf-8", response.content_type
        assert_includes response.body, "<loc>http://www.example.com/</loc>"
        assert_includes response.body, "<loc>http://www.example.com/register</loc>"
        assert_not_includes response.body, "<loc>http://www.example.com/about</loc>"
      end
    end
  end

  test "sitemap includes legal pages when private templates exist" do
    write_legal_page("terms", :en, "<section><h1>Terms</h1></section>")

    get sitemap_path(format: :xml)

    assert_response :success
    assert_includes response.body, "<loc>http://www.example.com/agb</loc>"
    assert_not_includes response.body, "<loc>http://www.example.com/datenschutz</loc>"
  end

  test "sitemap includes private marketing pages when private templates exist" do
    Dir.mktmpdir do |private_views|
      views = Pathname.new(private_views)
      views.join("pages").mkpath
      views.join("pages/about.html.erb").write("<h1>About</h1>")

      with_private_view_root(views) do
        get sitemap_path(format: :xml)

        assert_response :success
        assert_includes response.body, "<loc>http://www.example.com/about</loc>"
      end
    end
  end

  test "robots.txt references the sitemap" do
    get robots_path

    assert_response :success
    assert_equal "text/plain; charset=utf-8", response.content_type
    assert_includes response.body, "Sitemap: http://www.example.com/sitemap.xml"
    assert_includes response.body, "Allow: /"
  end

  test "sitemap is reachable for search console crawler user agents" do
    get sitemap_path(format: :xml), headers: {
      "User-Agent" => "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 " \
                      "(KHTML, like Gecko) Chrome/41.0.2272.96 Mobile Safari/537.36 " \
                      "(compatible; Google-Site-Verification/1.0)"
    }

    assert_response :success
    assert_includes response.body, "<urlset"
  end

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
