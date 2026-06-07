require "application_system_test_case"

class PasswordVisibilityTest < ApplicationSystemTestCase
  test "login page renders password visibility toggle" do
    visit login_path

    assert_selector "[data-controller='password-visibility']"
    assert_selector "button[data-action='password-visibility#toggle']"
  end

  test "register page renders password visibility toggles for both fields" do
    visit register_path

    assert_selector "button[data-action='password-visibility#toggle']", count: 2
  end
end
