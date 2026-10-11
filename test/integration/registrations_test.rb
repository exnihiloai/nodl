require "test_helper"

class RegistrationsTest < ActionDispatch::IntegrationTest
  test "registration form asks only for email and password" do
    get register_path

    assert_response :success
    assert_select "input[name=email]"
    assert_select "input[name=password]"
    assert_select "input[name=email_confirm]", count: 0
    assert_select "input[name=password_confirm]", count: 0
    assert_select "[data-testid=trial-terms]", text: I18n.t("registrations_view.new.trial_terms")
  end

  test "registering signs the user in and records the login time" do
    freeze_time do
      post register_path, params: { email: "new-signup@example.com", password: "ValidPass123", accept_legal: "1" }

      assert_redirected_to dashboard_path
      user = User.find_by!(email: "new-signup@example.com")
      assert_equal Time.current, user.last_login_at
      assert_equal user.id, session[:user_id]
    end
  end

  test "registration still enforces the password rules" do
    assert_no_difference "User.count" do
      post register_path, params: { email: "weak@example.com", password: "alllowercase", accept_legal: "1" }
    end

    assert_response :unprocessable_entity
  end
end
