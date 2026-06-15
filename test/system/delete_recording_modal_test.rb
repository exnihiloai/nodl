require "application_js_system_test_case"

class DeleteRecordingModalTest < ApplicationJsSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "dashboard delete uses styled modal and removes the last row" do
    recording_session = create_completed_recording(title: "Dashboard delete")

    visit dashboard_path

    within("[data-testid='dashboard-activity-item']", text: "Dashboard delete") do
      find("[data-testid='dashboard-recording-actions-menu-button']").click
      find("[data-testid='dashboard-delete-recording']").click
    end

    assert_selector "dialog.modal[open]"
    assert_text 'Delete "Dashboard delete"?'
    within("dialog.modal") { click_button "Cancel" }
    assert_no_selector "dialog.modal[open]"
    assert RecordingSession.exists?(recording_session.id)

    within("[data-testid='dashboard-activity-item']", text: "Dashboard delete") do
      find("[data-testid='dashboard-recording-actions-menu-button']").click
      find("[data-testid='dashboard-delete-recording']").click
    end
    assert_selector "dialog.modal[open]"
    within("dialog.modal") { click_button "Delete" }

    assert_text 'Recording "Dashboard delete" was permanently deleted.'
    assert_text "No recordings yet"
    assert_not RecordingSession.exists?(recording_session.id)
  end

  test "detail delete uses styled modal and redirects to dashboard" do
    recording_session = create_completed_recording(title: "Detail delete")

    visit recording_session_path(recording_session)
    find("[data-testid='recording-actions-menu-button']").click
    find("[data-testid='recording-delete-button']").click

    assert_selector "dialog.modal[open]"
    assert_text 'Delete "Detail delete"?'
    within("dialog.modal") { click_button "Delete" }

    assert_current_path dashboard_path, ignore_query: true
    assert_text 'Recording "Detail delete" was permanently deleted.'
    assert_not RecordingSession.exists?(recording_session.id)
  end

  test "mobile swipe reveals delete and only threshold opens confirm modal" do
    create_completed_recording(title: "Swipe delete")
    page.driver.browser.manage.window.resize_to(390, 900)

    visit dashboard_path
    assert_selector "[data-testid='dashboard-activity-item']", text: "Swipe delete"

    swipe_recording_row(offset: 50)
    assert_no_selector "dialog.modal[open]"
    assert_selector "[data-testid='dashboard-activity-item']", text: "Swipe delete"

    swipe_recording_row(offset: 130)
    assert_selector "dialog.modal[open]"
    assert_text 'Delete "Swipe delete"?'
    within("dialog.modal") { click_button "Cancel" }
  end

  private

  def create_completed_recording(title:)
    email = unique_email("delete-recording")
    @user ||= create_user_with_workspace(email: email, password: "Valid123")
    workspace = @user.workspaces.first
    recording_session = workspace.recording_sessions.create!(
      creator: @user,
      title: title,
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    recording_session.mark_completed!(
      transcript_text: "Transcript",
      document_content: "# Document",
      work_path: "/tmp/#{title.parameterize}"
    )

    login_via_ui(email: @user.email, password: "Valid123")
    assert_selector "[data-testid='account-menu']"
    recording_session
  end

  def swipe_recording_row(offset:)
    page.execute_script(<<~JS, offset)
      const offset = arguments[0];
      const row = document.querySelector("[data-testid='dashboard-activity-item']");
      const surface = row.querySelector("[data-swipe-delete-target='surface']");
      const rect = surface.getBoundingClientRect();
      const startX = rect.right - 20;
      const y = rect.top + rect.height / 2;
      const options = { bubbles: true, pointerId: 7, pointerType: "touch", clientY: y };
      surface.dispatchEvent(new PointerEvent("pointerdown", { ...options, clientX: startX }));
      surface.dispatchEvent(new PointerEvent("pointermove", { ...options, clientX: startX - offset }));
      surface.dispatchEvent(new PointerEvent("pointerup", { ...options, clientX: startX - offset }));
    JS
  end
end
