require "test_helper"

class ContentPageCtaTest < ActionDispatch::IntegrationTest
  setup do
    @private_views = Rails.root.join("tmp/content_page_cta_test/#{SecureRandom.hex(8)}/views")
    @private_views.join("content/de").mkpath
    @private_views.join("content/en").mkpath
    article = <<~ERB
      <article><h2>Eins</h2><%= render "content_pages/inline_cta" %><h2>Zwei</h2></article>
    ERB
    @private_views.join("content/de/einwilligungserklaerung-interview.html.erb").write(article)
    @private_views.join("content/de/psychotherapie-dokumentation.html.erb").write(article)
    @private_views.join("content/en/best-voice-journaling-apps.html.erb").write(article)
  end

  teardown do
    FileUtils.rm_rf(@private_views.dirname)
  end

  test "interview article pitches interview transcription" do
    with_private_view_root(@private_views) do
      get "/artikel/einwilligungserklaerung-interview"

      assert_response :success
      assert_select "[data-testid=article-inline-cta] a[href='#{register_path}']",
                    text: I18n.t("content_pages.cta.interview.button", locale: :de)
    end
  end

  test "practice article pitches session documentation" do
    with_private_view_root(@private_views) do
      get "/artikel/psychotherapie-dokumentation"

      assert_select "[data-testid=article-inline-cta]", text: /#{Regexp.escape(I18n.t("content_pages.cta.practice.heading", locale: :de))}/
    end
  end

  test "english journaling article pitches in english" do
    with_private_view_root(@private_views) do
      get "/articles/best-voice-journaling-apps"

      assert_select "[data-testid=article-inline-cta]", text: /#{Regexp.escape(I18n.t("content_pages.cta.journal.heading", locale: :en))}/
    end
  end

  test "signed-out readers get the sticky sign-up bar" do
    with_private_view_root(@private_views) do
      get "/artikel/einwilligungserklaerung-interview"

      assert_select "[data-testid=article-sticky-cta][data-controller=article-cta]" do
        assert_select "a[href='#{register_path}']"
      end
    end
  end

  test "signed-in users do not get the sticky sign-up bar" do
    user = create_user_with_workspace(email: "reader@example.com")
    post login_path, params: { email: user.email, password: "Valid123" }

    with_private_view_root(@private_views) do
      get "/artikel/einwilligungserklaerung-interview"

      assert_select "[data-testid=article-sticky-cta]", count: 0
    end
  end

  test "pages other than articles do not get the sticky bar" do
    get register_path

    assert_select "[data-testid=article-sticky-cta]", count: 0
  end
end
