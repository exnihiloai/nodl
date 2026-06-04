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

  test "dashboard smoke renders recording hub and empty activity feed" do
    email = unique_email("dashboard-product")
    create_user_with_workspace(email: email, password: "Valid123", workspace_name: "Audio Workspace")

    login_via_ui(email: email, password: "Valid123")

    assert_selector "[data-testid='record-hero']"
    assert_selector "[data-testid='recording-form'][data-controller~='audio-recorder']"
    assert_selector "[data-testid='record-button']"
    assert_selector "[data-testid='audio-upload-input']", visible: :all
    assert_selector "[data-testid='output-type-select']"
    assert_selector "[data-testid='output-types-panel']"
    assert_selector "[data-testid='dashboard-activity']"
    assert_text "No recordings yet"
    assert_selector "turbo-cable-stream-source"
  end

  test "dashboard smoke renders durable activity states" do
    email = unique_email("dashboard-activity")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first

    processing_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Processing note",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    processing_session.mark_processing!

    completed_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Completed note",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    completed_session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Completed",
      work_path: "/tmp/completed"
    )

    failed_session = workspace.recording_sessions.create!(
      creator: user,
      title: "Failed note",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    failed_session.mark_failed!("Could not process")

    login_via_ui(email: email, password: "Valid123")

    within("[data-testid='dashboard-activity']") do
      assert_selector "[data-testid='dashboard-activity-item'][data-status='processing']", text: "Processing note"
      assert_selector "[data-testid='dashboard-activity-item'][data-status='completed']", text: "Completed note"
      assert_selector "[data-testid='dashboard-activity-item'][data-status='failed']", text: "Failed note"
      assert_link "Open document", href: document_path(completed_session.document)
      assert_link "view", href: recording_session_path(failed_session)
    end
  end

  test "user can create an upload recording session from the dashboard" do
    email = unique_email("dashboard-upload")
    user = create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")
    assert_selector "[data-testid='audio-upload-input']", visible: :all
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
