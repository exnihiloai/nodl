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

  test "multi-speaker copy payload contains annotated speaker turns while visible transcript stays clean" do
    session = completed_session(segments: [
      { "speaker" => "speaker_1", "text" => "Speaker 1: Auf Ostersonntag.", "start" => 0.0, "end" => 2.0 },
      { "speaker" => "speaker_1", "text" => "Noch immer ich.", "start" => 2.0, "end" => 3.0 },
      { "speaker" => "speaker_2", "text" => "Speaker 2: Der Laptop ist neu.", "start" => 3.0, "end" => 4.0 },
      { "speaker" => "speaker_1", "text" => "Speaker 1: Wieder da.", "start" => 4.0, "end" => 5.0 }
    ])

    speakers_label = I18n.t("recording_sessions.interactive.speakers", count: 2)
    person_one_label = I18n.t("recording_sessions.interactive.speaker", number: 1)

    get recording_session_path(session)

    assert_response :success
    # The speaker legend renders on the page...
    assert_select "section", text: /#{Regexp.escape(speakers_label)}/
    assert_select "section", text: /#{Regexp.escape(person_one_label)}/

    # ...but the visible transcript stays clean.
    assert_select "[data-clipboard-target='source']" do |elements|
      source_html = elements.first.to_s
      assert_includes source_html, "Auf Ostersonntag."
      refute_match(/Speaker\s*1/, source_html)
      refute_match(/#{Regexp.escape(speakers_label)}/, source_html)
    end

    assert_select "section[data-controller='clipboard']" do |elements|
      clipboard = elements.first
      assert_equal(
        "[Person 1] Auf Ostersonntag. Noch immer ich.\n\n[Person 2] Der Laptop ist neu.\n\n[Person 1] Wieder da.",
        clipboard["data-clipboard-plain-text-value"]
      )
      assert_includes clipboard["data-clipboard-html-value"], "<p><strong>[Person 1]</strong> Auf Ostersonntag. Noch immer ich.</p>"
      assert_includes clipboard["data-clipboard-html-value"], "<p><strong>[Person 2]</strong> Der Laptop ist neu.</p>"
    end
  end

  test "multi-speaker copy payload uses labels from the active locale" do
    session = completed_session(segments: [
      { "speaker" => "speaker_1", "text" => "Speaker 1: Guten Tag.", "start" => 0.0, "end" => 2.0 },
      { "speaker" => "speaker_2", "text" => "Speaker 2: Hallo.", "start" => 2.0, "end" => 4.0 }
    ])
    patch locale_path(locale: :de)

    get recording_session_path(session)

    assert_response :success
    expected_one = I18n.t("recording_sessions.interactive.speaker", number: 1, locale: :de)
    expected_two = I18n.t("recording_sessions.interactive.speaker", number: 2, locale: :de)
    assert_select "section[data-controller='clipboard']" do |elements|
      text = elements.first["data-clipboard-plain-text-value"]
      assert_equal "[#{expected_one}] Guten Tag.\n\n[#{expected_two}] Hallo.", text
    end
  end

  test "single-speaker copy keeps the clean visible transcript without clipboard overrides" do
    session = completed_session(segments: [
      { "speaker" => "speaker_1", "text" => "Speaker 1: Auf Ostersonntag.", "start" => 0.0, "end" => 2.0 },
      { "speaker" => "speaker_1", "text" => "Nur eine Person.", "start" => 2.0, "end" => 4.0 }
    ])

    get recording_session_path(session)

    assert_response :success
    assert_select "section[data-controller='clipboard']:not([data-clipboard-plain-text-value]):not([data-clipboard-html-value])"
  end

  test "copy source falls back to plain transcript text without segments" do
    session = completed_session(segments: nil, transcript_text: "Plain transcript body.")

    get recording_session_path(session)

    assert_response :success
    assert_select "[data-testid='copy-transcript']"
    assert_select "[data-clipboard-target='source']", text: /Plain transcript body\./
    assert_select "section[data-controller='clipboard']:not([data-clipboard-plain-text-value]):not([data-clipboard-html-value])"
  end
end
