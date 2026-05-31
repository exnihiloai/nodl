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

  test "dashboard shows recording tools and empty product sections" do
    email = unique_email("dashboard-product")
    create_user_with_workspace(email: email, password: "Valid123", workspace_name: "Audio Workspace")

    login_via_ui(email: email, password: "Valid123")

    assert_text "Speak. We'll structure it."
    assert_text "Record"
    assert_text "Default Transformer"
    assert_text "Recent"
    assert_text "Output types"
    assert_text "No recordings yet"
    assert_selector "turbo-cable-stream-source"
  end

  test "user can create an upload recording session from the dashboard" do
    email = unique_email("dashboard-upload")
    user = create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")
    attach_file "recording_session_original_audio", Rails.root.join("test", "fixtures", "files", "sample.mp3")

    assert_enqueued_with(job: ProcessRecordingSessionJob) do
      click_button "Create document"
    end

    assert_current_path dashboard_path, ignore_query: true
    assert_text "Recording session created. Processing has started."
    assert_text "Untitled recording"
    assert_equal "Untitled recording", user.workspaces.first.recording_sessions.first.title
  end
end
