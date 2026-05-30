require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  private

  def unique_email(prefix = "user")
    "#{prefix}-#{SecureRandom.hex(4)}@example.test"
  end

  def create_user_with_workspace(email:, password: "Valid123", role: :user, active: true, workspace_name: nil)
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      role: role,
      active: active
    )

    workspace = Workspace.create!(
      name: workspace_name || "#{email.split("@").first.titleize} Workspace",
      usage_limits: { scans: 1000, storage_mb: 1024 },
      usage_consumption: { scans: 0, storage_mb: 0 }
    )

    Membership.create!(user: user, workspace: workspace, role: :owner)
    user
  end

  def register_via_ui(email:, password:)
    visit register_path
    fill_in "email", with: email
    fill_in "email_confirm", with: email
    fill_in "password", with: password
    fill_in "password_confirm", with: password
    click_button "Create account"
  end

  def login_via_ui(email:, password:)
    visit login_path
    fill_in "login_email", with: email
    fill_in "login_password", with: password
    click_button "Sign in"
  end
end
