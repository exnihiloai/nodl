require "test_helper"

class LocaleSwitchingTest < ActionDispatch::IntegrationTest
  test "landing page renders in english by default" do
    get root_path
    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_includes response.body, I18n.t("nav.login", locale: :en)
  end

  test "accept language header selects german automatically" do
    get root_path, headers: { "Accept-Language" => "de-DE,de;q=0.9,en;q=0.8" }
    assert_response :success
    assert_select "html[lang=?]", "de"
    assert_includes response.body, I18n.t("nav.login", locale: :de)
  end

  test "landing page exposes a flag-free language switcher" do
    get root_path
    assert_select "[data-testid=language-switcher]"
    assert_select "[data-testid=?]", "language-option-de"
    assert_select "[data-testid=?]", "language-option-en"
    # Languages are named by endonym, never by country/flag.
    assert_includes response.body, "Deutsch"
  end

  test "switching to german persists in the session and translates the page" do
    patch locale_path(locale: "de")
    assert_redirected_to root_path

    get root_path
    assert_select "html[lang=?]", "de"
    assert_includes response.body, I18n.t("nav.login", locale: :de)
  end

  test "unsupported locale is ignored and falls back to default" do
    patch locale_path(locale: "fr")
    get root_path
    assert_select "html[lang=?]", "en"
  end

  test "signed-in user language choice is saved to their account" do
    user = create_user_with_workspace
    post login_path, params: { email: user.email, password: "Valid123" }

    patch locale_path(locale: "de")
    assert_equal "de", user.reload.preferred_language

    get dashboard_path
    assert_select "html[lang=?]", "de"
    assert_includes response.body, I18n.t("nav.dashboard", locale: :de)
  end

  test "returning user sees their saved language preference" do
    user = create_user_with_workspace
    user.update!(preferred_language: "de")
    post login_path, params: { email: user.email, password: "Valid123" }

    get dashboard_path
    assert_select "html[lang=?]", "de"
  end
end
