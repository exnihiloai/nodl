require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user_with_workspace
    post login_path, params: { email: @user.email, password: "Valid123" }
  end

  teardown do
    @user&.destroy
  end

  test "requires authentication" do
    delete logout_path
    get settings_path
    assert_redirected_to login_path
  end

  test "shows settings page for signed in user" do
    get settings_path
    assert_response :success
    assert_includes response.body, I18n.t("settings.daily_reminder.heading")
  end

  test "updates daily reminder preferences" do
    patch settings_path, params: {
      user: {
        daily_reminder_enabled: "1",
        daily_reminder_at: "21:00",
        daily_reminder_message: "Time to nodl",
        time_zone: "Europe/Vienna"
      }
    }

    assert_redirected_to settings_path
    @user.reload
    assert @user.daily_reminder_enabled?
    assert_equal "Europe/Vienna", @user.time_zone
    assert_equal "Time to nodl", @user.daily_reminder_message
  end

  test "rejects reminder message longer than 30 characters" do
    patch settings_path, params: {
      user: {
        daily_reminder_enabled: "1",
        daily_reminder_at: "21:00",
        daily_reminder_message: "a" * 31,
        time_zone: "Europe/Vienna"
      }
    }

    assert_response :unprocessable_entity
    assert_not @user.reload.daily_reminder_enabled?
  end
end
