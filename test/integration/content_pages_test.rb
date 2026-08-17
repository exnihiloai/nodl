require "test_helper"

# Operator articles live at private/views/content/<locale>/<slug>.html.erb and
# are served under /artikel (German) and /articles (English). Deployments
# without private content 404, mirroring the marketing page contract.
class ContentPagesTest < ActionDispatch::IntegrationTest
  setup do
    @private_views = Rails.root.join("tmp/content_pages_test/#{SecureRandom.hex(8)}/views")
    @private_views.join("content/de").mkpath
    @private_views.join("content/en").mkpath
    @private_views.join("content/de/tagebuch-diktieren.html.erb").write(<<~ERB)
      <% content_for :title, "Tagebuch diktieren: Der komplette Guide – Nodl" %>
      <% content_for :head do %>
        <meta name="description" content="So diktierst du dein Tagebuch." />
      <% end %>
      <h1>DE Artikel</h1><p>locale=<%= I18n.locale %></p>
    ERB
    @private_views.join("content/en/voice-journaling.html.erb").write(<<~ERB)
      <% content_for :title, "Voice Journaling Guide – Nodl" %>
      <% content_for :head do %>
        <meta name="description" content="How to journal by speaking." />
      <% end %>
      <h1>EN article</h1><p>locale=<%= I18n.locale %></p>
    ERB
    @private_views.join("content/de/ohne-meta.html.erb").write("<h1>Ohne Meta</h1>")

    # A translated pair drawn from SeoHelper::CONTENT_PAGE_PAIRS, used for the
    # hreflang assertions below.
    @private_views.join("content/de/interview-transkribieren.html.erb").write("<h1>DE Zwilling</h1>")
    @private_views.join("content/en/how-to-transcribe-an-interview.html.erb").write("<h1>EN twin</h1>")
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

  test "translated articles cross-link via hreflang from both sides" do
    with_private_view_root(@private_views) do
      get "/artikel/interview-transkribieren"

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/artikel/interview-transkribieren"
      assert_select "link[rel=alternate][hreflang=de][href=?]", "https://nodl.now/artikel/interview-transkribieren"
      assert_select "link[rel=alternate][hreflang=en][href=?]", "https://nodl.now/articles/how-to-transcribe-an-interview"
      assert_select "link[rel=alternate][hreflang=x-default][href=?]", "https://nodl.now/articles/how-to-transcribe-an-interview"

      get "/articles/how-to-transcribe-an-interview"

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/articles/how-to-transcribe-an-interview"
      assert_select "link[rel=alternate][hreflang=de][href=?]", "https://nodl.now/artikel/interview-transkribieren"
      assert_select "link[rel=alternate][hreflang=en][href=?]", "https://nodl.now/articles/how-to-transcribe-an-interview"
    end
  end

  test "untranslated articles keep a plain self-canonical without hreflang" do
    with_private_view_root(@private_views) do
      get "/artikel/tagebuch-diktieren"

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/artikel/tagebuch-diktieren"
      assert_select "link[rel=alternate][hreflang]", false
    end
  end

  test "hreflang is omitted when only one half of a pair is deployed" do
    Dir.mktmpdir do |root|
      views = Pathname.new(root).join("views")
      views.join("content/de").mkpath
      views.join("content/en").mkpath
      views.join("content/de/interview-transkribieren.html.erb").write("<h1>DE only</h1>")

      with_private_view_root(views) do
        get "/artikel/interview-transkribieren"

        assert_response :success
        assert_select "link[rel=canonical][href=?]", "https://nodl.now/artikel/interview-transkribieren"
        assert_select "link[rel=alternate][hreflang]", false
      end
    end
  end

  test "hub offers a language switch only for translated articles" do
    with_private_view_root(@private_views) do
      get "/artikel"

      assert_select "a[href=?]", "/articles/how-to-transcribe-an-interview"
      # tagebuch-diktieren has no twin, so no switch is rendered for it
      assert_select "a[href=?]", "/articles/tagebuch-diktieren", false
    end
  end

  test "hub language switch points back from the English side" do
    with_private_view_root(@private_views) do
      get "/articles"

      assert_select "a[href=?]", "/artikel/interview-transkribieren"
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

  test "german hub lists articles with metadata parsed from templates" do
    with_private_view_root(@private_views) do
      get "/artikel"

      assert_response :success
      assert_includes response.body, "Tagebuch diktieren: Der komplette Guide"
      assert_not_includes response.body, "Der komplette Guide – Nodl"
      assert_includes response.body, "So diktierst du dein Tagebuch."
      assert_select "a[href=?]", "/artikel/tagebuch-diktieren"
      assert_select "footer a[href=?]", "/artikel"
    end
  end

  test "hub falls back to a humanized slug when a template has no title" do
    with_private_view_root(@private_views) do
      get "/artikel"

      assert_select "a[href=?]", "/artikel/ohne-meta", text: /Ohne meta/
    end
  end

  test "german hub declares canonical and hreflang pair" do
    with_private_view_root(@private_views) do
      get "/artikel"

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/artikel"
      assert_select "link[rel=alternate][hreflang=de][href=?]", "https://nodl.now/artikel"
      assert_select "link[rel=alternate][hreflang=en][href=?]", "https://nodl.now/articles"
    end
  end

  test "english hub renders with forced English locale" do
    with_private_view_root(@private_views) do
      get "/articles", headers: { "Accept-Language" => "de-DE,de;q=0.9" }

      assert_response :success
      assert_includes response.body, "Voice Journaling Guide"
      assert_select "a[href=?]", "/articles/voice-journaling"
      assert_select "link[rel=canonical][href=?]", "https://nodl.now/articles"
    end
  end

  test "hub 404s without private content" do
    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        get "/artikel"

        assert_response :not_found
      end
    end
  end

  test "sitemap lists hubs and articles from both locales" do
    with_private_view_root(@private_views) do
      get sitemap_path(format: :xml)

      assert_response :success
      assert_includes response.body, "<loc>http://www.example.com/artikel</loc>"
      assert_includes response.body, "<loc>http://www.example.com/articles</loc>"
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
