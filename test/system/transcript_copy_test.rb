require "application_js_system_test_case"

class TranscriptCopyTest < ApplicationJsSystemTestCase
  test "copy button copies the transcript and shows feedback" do
    session = create_completed_session

    visit recording_session_path(session)

    assert_selector "[data-testid='copy-transcript']", text: "Copy"
    find("[data-testid='copy-transcript']").click

    assert_selector "[data-testid='copy-transcript']", text: "Copied"
  end

  private

  def create_completed_session
    email = unique_email
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    session = workspace.recording_sessions.new(
      creator: user,
      title: "Laptop chat",
      transformer_handle: "default"
    )
    attach_sample_audio(session)
    session.save!
    session.update!(
      status: :completed,
      transcript_text: "Auf Ostersonntag.",
      transcript_segments: [
        { "speaker" => "speaker_1", "text" => "Speaker 1: Auf Ostersonntag.", "start" => 0.0, "end" => 2.0 },
        { "speaker" => "speaker_2", "text" => "Speaker 2: Der Laptop ist neu.", "start" => 2.0, "end" => 4.0 }
      ]
    )

    login_via_ui(email: email, password: "Valid123")
    assert_selector "[data-testid='account-menu']"
    session
  end
end
