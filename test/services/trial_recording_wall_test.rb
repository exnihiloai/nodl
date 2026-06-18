require "test_helper"

class TrialRecordingWallTest < ActiveSupport::TestCase
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
  end

  test "lists the documents created with their titles" do
    completed_with_document(title: "Kickoff notes", audio_duration: 60)
    completed_with_document(title: "Client call", audio_duration: 60)

    wall = TrialRecordingWall.new(@workspace)

    assert_equal 2, wall.documents_count
    assert_equal [ "Kickoff notes", "Client call" ].sort, wall.documents.map(&:title).sort
  end

  test "sums time saved across the completed recordings" do
    # 60s -> 600s effort, 600s -> 3600s effort; total 4200s == 70 minutes.
    completed_with_document(title: "Short", audio_duration: 60)
    completed_with_document(title: "Long", audio_duration: 600)

    wall = TrialRecordingWall.new(@workspace)

    assert_in_delta 4200, wall.total_time_saved_seconds, 0.01
    assert_equal 70, wall.total_time_saved_minutes
  end

  test "is empty without any documents" do
    wall = TrialRecordingWall.new(@workspace)

    assert_equal 0, wall.documents_count
    assert_equal 0, wall.total_time_saved_minutes
  end

  private

  def completed_with_document(title:, audio_duration:)
    session = @workspace.recording_sessions.create!(
      creator: @user,
      title: title,
      transformer_handle: "default",
      status: :completed,
      audio_duration: audio_duration
    ) { |s| attach_sample_audio(s) }
    session.create_document!(
      workspace: @workspace,
      transformer_handle: "default",
      title: title,
      content: "# #{title}",
      generated_at: Time.current
    )
    session
  end
end
