require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test
  include ActiveJob::TestHelper

  private

  def register_via_ui(email:, password:)
    visit register_path
    fill_in "email", with: email
    fill_in "email_confirm", with: email
    fill_in "password", with: password
    fill_in "password_confirm", with: password
    check "accept_legal" if has_field?("accept_legal")
    click_button "Create account"
  end

  def login_via_ui(email:, password:)
    visit login_path
    fill_in "login_email", with: email
    fill_in "login_password", with: password
    click_button "Sign in"
  end
end
