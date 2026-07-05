require "test_helper"

# Vertical marketing pages exist once per language: the URL fixes the locale so
# crawlers index a stable language per URL (/fuer/* is German, /for/* is
# English), and both variants reference each other via hreflang.
class LocalizedMarketingPagesTest < ActionDispatch::IntegrationTest
  EN_TWINS = {
    "/fuer/aerzte" => "/for/doctors",
    "/fuer/zahnaerzte" => "/for/dentists",
    "/fuer/gedankenkarussell" => "/for/racing-mind",
    "/fuer/tagebuch" => "/for/journaling",
    "/fuer/interviews" => "/for/interviews",
    "/fuer/coaches" => "/for/coaches"
  }.freeze

  ACTIONS = %i[for_doctors for_dentists for_overthinkers for_journaling for_interviews for_coaches].freeze

  setup do
    @private_views = Rails.root.join("tmp/localized_marketing_pages_test/#{SecureRandom.hex(8)}/views")
    @private_views.join("pages").mkpath
    ACTIONS.each do |action|
      @private_views.join("pages/#{action}.html.erb").write(
        "<h1>#{action} fixture</h1><p data-testid='locale-probe'>locale=<%= I18n.locale %></p>"
      )
    end
  end

  teardown do
    FileUtils.rm_rf(@private_views.dirname)
  end

  test "german vertical URLs render German even for English browsers" do
    with_private_view_root(@private_views) do
      get "/fuer/tagebuch", headers: { "Accept-Language" => "en-US,en;q=0.9" }

      assert_response :success
      assert_includes response.body, "locale=de"
    end
  end

  test "english vertical URLs render English even for German browsers" do
    with_private_view_root(@private_views) do
      EN_TWINS.each_value do |en_path|
        get en_path, headers: { "Accept-Language" => "de-DE,de;q=0.9" }

        assert_response :success, "expected #{en_path} to render"
        assert_includes response.body, "locale=en", "expected #{en_path} to render English"
      end
    end
  end

  test "session language choice does not override the URL language" do
    with_private_view_root(@private_views) do
      patch locale_path(locale: "en")
      get "/fuer/tagebuch"

      assert_response :success
      assert_includes response.body, "locale=de"
    end
  end

  test "vertical pages declare canonical and hreflang alternates" do
    with_private_view_root(@private_views) do
      get "/fuer/tagebuch"

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/fuer/tagebuch"
      assert_select "link[rel=alternate][hreflang=de][href=?]", "https://nodl.now/fuer/tagebuch"
      assert_select "link[rel=alternate][hreflang=en][href=?]", "https://nodl.now/for/journaling"
      assert_select "link[rel=alternate][hreflang=x-default][href=?]", "https://nodl.now/for/journaling"

      get "/for/journaling"

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/for/journaling"
      assert_select "link[rel=alternate][hreflang=de][href=?]", "https://nodl.now/fuer/tagebuch"
    end
  end

  test "homepage declares a self-canonical" do
    with_private_view_root(@private_views) do
      get root_path

      assert_select "link[rel=canonical][href=?]", "https://nodl.now/"
    end
  end

  test "sitemap lists english twins when marketing is mounted" do
    with_private_view_root(@private_views) do
      get sitemap_path(format: :xml)

      assert_response :success
      assert_includes response.body, "<loc>http://www.example.com/fuer/tagebuch</loc>"
      assert_includes response.body, "<loc>http://www.example.com/for/journaling</loc>"
    end
  end

  test "english twins 404 without private views like their german siblings" do
    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        get "/for/journaling"

        assert_response :not_found
      end
    end
  end
end
