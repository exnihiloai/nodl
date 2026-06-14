require "test_helper"

class TranscriptCopyTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
    post login_path, params: { email: @user.email, password: "Valid123" }
  end

  def completed_session(segments:, transcript_text: "fallback text")
    session = @workspace.recording_sessions.new(
      creator: @user,
      title: "Laptop chat",
      transformer_handle: "default"
    )
    attach_sample_audio(session)
    session.save!
    session.update!(status: :completed, transcript_segments: segments, transcript_text: transcript_text)
    session
  end

  test "copy button is shown for a completed transcript" do
    session = completed_session(segments: [
      { "speaker" => "speaker_1", "text" => "Speaker 1: Auf Ostersonntag.", "start" => 0.0, "end" => 2.0 }
    ])

    get recording_session_path(session)

    assert_response :success
    assert_select "[data-testid='copy-transcript']"
  end

  test "copy source excludes the speaker legend tags" do
    session = completed_session(segments: [
      { "speaker" => "speaker_1", "text" => "Speaker 1: Auf Ostersonntag.", "start" => 0.0, "end" => 2.0 },
      { "speaker" => "speaker_2", "text" => "Speaker 2: Der Laptop ist neu.", "start" => 2.0, "end" => 4.0 }
    ])

    speakers_label = I18n.t("recording_sessions.interactive.speakers", count: 2)
    person_one_label = I18n.t("recording_sessions.interactive.speaker", number: 1)

    get recording_session_path(session)

    assert_response :success
    # The speaker legend renders on the page...
    assert_select "section", text: /#{Regexp.escape(speakers_label)}/
    assert_select "section", text: /#{Regexp.escape(person_one_label)}/

    # ...but is not inside the copyable source, and the spoken text is.
    assert_select "[data-clipboard-target='source']" do |elements|
      source_html = elements.first.to_s
      assert_includes source_html, "Auf Ostersonntag."
      refute_match(/Speaker\s*1/, source_html)
      refute_match(/#{Regexp.escape(speakers_label)}/, source_html)
    end
  end

  test "copy source falls back to plain transcript text without segments" do
    session = completed_session(segments: nil, transcript_text: "Plain transcript body.")

    get recording_session_path(session)

    assert_response :success
    assert_select "[data-testid='copy-transcript']"
    assert_select "[data-clipboard-target='source']", text: /Plain transcript body\./
  end
end
