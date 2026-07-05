require "test_helper"

# Operator articles live at private/views/content/<locale>/<slug>.html.erb and
# are served under /artikel (German) and /articles (English). Deployments
# without private content 404, mirroring the marketing page contract.
class ContentPagesTest < ActionDispatch::IntegrationTest
  setup do
    @private_views = Rails.root.join("tmp/content_pages_test/#{SecureRandom.hex(8)}/views")
    @private_views.join("content/de").mkpath
    @private_views.join("content/en").mkpath
    @private_views.join("content/de/tagebuch-diktieren.html.erb").write(
      "<h1>DE Artikel</h1><p>locale=<%= I18n.locale %></p>"
    )
    @private_views.join("content/en/voice-journaling.html.erb").write(
      "<h1>EN article</h1><p>locale=<%= I18n.locale %></p>"
    )
  end

  teardown do
    FileUtils.rm_rf(@private_views.dirname)
  end

  test "german article renders with forced German locale" do
    with_private_view_root(@private_views) do
      get "/artikel/tagebuch-diktieren", headers: { "Accept-Language" => "en-US,en;q=0.9" }

      assert_response :success
      assert_includes response.body, "DE Artikel"
      assert_includes response.body, "locale=de"
    end
  end

  test "english article renders with forced English locale" do
    with_private_view_root(@private_views) do
      get "/articles/voice-journaling", headers: { "Accept-Language" => "de-DE,de;q=0.9" }

      assert_response :success
      assert_includes response.body, "EN article"
      assert_includes response.body, "locale=en"
    end
  end

  test "articles declare a self-canonical link" do
    with_private_view_root(@private_views) do
      get "/artikel/tagebuch-diktieren"

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/artikel/tagebuch-diktieren"
    end
  end

  test "unknown article returns not found" do
    with_private_view_root(@private_views) do
      get "/artikel/gibt-es-nicht"

      assert_response :not_found
    end
  end

  test "article from the other locale namespace is not reachable" do
    with_private_view_root(@private_views) do
      get "/articles/tagebuch-diktieren"

      assert_response :not_found
    end
  end

  test "malformed slugs are rejected" do
    with_private_view_root(@private_views) do
      get "/artikel/-fuehrender-strich"

      assert_response :not_found
    end
  end

  test "articles 404 without private content" do
    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        get "/artikel/tagebuch-diktieren"

        assert_response :not_found
      end
    end
  end

  test "sitemap lists articles from both locales" do
    with_private_view_root(@private_views) do
      get sitemap_path(format: :xml)

      assert_response :success
      assert_includes response.body, "<loc>http://www.example.com/artikel/tagebuch-diktieren</loc>"
      assert_includes response.body, "<loc>http://www.example.com/articles/voice-journaling</loc>"
    end
  end

  test "sitemap omits articles without private content" do
    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        get sitemap_path(format: :xml)

        assert_response :success
        assert_not_includes response.body, "/artikel/"
        assert_not_includes response.body, "/articles/"
      end
    end
  end
end
