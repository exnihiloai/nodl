require "application_system_test_case"

class DashboardTenancyTest < ApplicationSystemTestCase
  test "dashboard requires authentication" do
    visit dashboard_path

    assert_current_path login_path, ignore_query: true
    assert_text "Please sign in to continue."
  end

  test "user can switch between workspaces" do
    email = unique_email("tenant")
    user = create_user_with_workspace(email: email, password: "Valid123", workspace_name: "Alpha Workspace")

    beta_workspace = Workspace.create!(
      name: "Beta Workspace",
      usage_limits: { scans: 500, storage_mb: 512 },
      usage_consumption: { scans: 10, storage_mb: 5 }
    )
    Membership.create!(user: user, workspace: beta_workspace, role: :member)

    login_via_ui(email: email, password: "Valid123")

    assert_text "Alpha Workspace"

    click_button "Beta Workspace"

    assert_current_path dashboard_path, ignore_query: true
    assert_text "Workspace switched to Beta Workspace."
    assert_text "Beta Workspace"
  end
end
