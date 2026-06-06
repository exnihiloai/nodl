require "application_system_test_case"

class AuthenticationFlowTest < ApplicationSystemTestCase
  test "user can register and is redirected to dashboard" do
    email = unique_email("register")

    register_via_ui(email: email, password: "Valid123")

    assert_current_path dashboard_path, ignore_query: true
    assert_selector "[data-testid='account-menu']"
    assert_text email
  end

  test "existing user can login and logout" do
    email = unique_email("login")
    create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")

    assert_current_path dashboard_path, ignore_query: true
    assert_selector "[data-testid='account-menu']"

    find("[data-testid='account-menu']").click
    find("[data-testid='logout-btn-desktop']").click

    assert_current_path root_path, ignore_query: true
    assert_text "You have been signed out."
  end

  test "deactivated user cannot login" do
    email = unique_email("inactive")
    create_user_with_workspace(email: email, password: "Valid123", active: false)

    login_via_ui(email: email, password: "Valid123")

    assert_current_path login_path, ignore_query: true
    assert_text "Invalid credentials."
  end
end
