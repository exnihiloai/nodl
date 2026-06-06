require "test_helper"

class ErrorsTest < ActionDispatch::IntegrationTest
  test "not found page renders friendly copy" do
    get "/404"

    assert_response :not_found
    assert_includes response.body, I18n.t("errors.not_found.heading", locale: :en)
    assert_includes response.body, I18n.t("errors.not_found.transcript_body", locale: :en)
  end

  test "not found page is localized in german" do
    patch locale_path(locale: :de)
    follow_redirect!

    get "/404"

    assert_response :not_found
    assert_includes response.body, I18n.t("errors.not_found.heading", locale: :de)
  end

  test "unknown routes use the friendly not found page" do
    get "/this-page-never-existed-nodl-test"

    assert_response :not_found
    assert_includes response.body, I18n.t("errors.not_found.heading", locale: :en)
  end
end
