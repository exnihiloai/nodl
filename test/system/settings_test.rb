require "application_system_test_case"

class SettingsSystemTest < ApplicationSystemTestCase
  test "signed in user can open settings from account menu" do
    email = unique_email("settings-menu")
    create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")

    find("[data-testid='account-menu']").click
    find("[data-testid='settings-link']").click

    assert_current_path settings_path
    assert_text I18n.t("settings.daily_reminder.heading")
    assert_field "user[daily_reminder_at]"
    assert_field "user[daily_reminder_message]"
  end
end
