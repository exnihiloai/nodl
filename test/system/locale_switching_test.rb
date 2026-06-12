require "application_system_test_case"

class LocaleSwitchingSystemTest < ApplicationSystemTestCase
  test "visitor can switch language from the landing page language switcher" do
    visit root_path

    assert_text I18n.t("nav.login", locale: :en)

    within("[data-testid='language-switcher']") do
      find("summary").click
      find("[data-testid='language-option-de']").click
    end

    assert_text I18n.t("nav.login", locale: :de)
    assert_selector "html[lang='de']", visible: :all
  end

  test "signed-in user can switch language from the account menu" do
    email = unique_email("locale-menu")
    create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")

    assert_text I18n.t("nav.dashboard", locale: :en)

    find("[data-testid='account-menu']").click
    find("[data-testid='language-option-de']").click

    assert_text I18n.t("nav.dashboard", locale: :de)
  end
end
