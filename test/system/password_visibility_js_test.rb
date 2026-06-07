require "application_js_system_test_case"

class PasswordVisibilityJsTest < ApplicationJsSystemTestCase
  test "password visibility toggle reveals and hides typed password on login" do
    visit login_path

    fill_in "login_password", with: "Secret123"
    toggle = find("button[data-action='password-visibility#toggle']")

    assert_equal "password", find_field("login_password")[:type]

    toggle.click
    assert_equal "text", find_field("login_password")[:type]
    assert_equal "Secret123", find_field("login_password").value

    toggle.click
    assert_equal "password", find_field("login_password")[:type]
  end

  test "registration form toggles each password field independently" do
    visit register_path

    fill_in "password", with: "Secret123"
    fill_in "password_confirm", with: "Secret456"

    toggles = all("button[data-action='password-visibility#toggle']")
    assert_equal 2, toggles.length

    toggles[0].click
    assert_equal "text", find_field("password")[:type]
    assert_equal "password", find_field("password_confirm")[:type]

    toggles[1].click
    assert_equal "text", find_field("password_confirm")[:type]
  end
end
