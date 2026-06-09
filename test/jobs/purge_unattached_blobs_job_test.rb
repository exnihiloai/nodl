require "test_helper"

class PurgeUnattachedBlobsJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper
  self.use_transactional_tests = false

  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
  end

  teardown do
    @workspace&.destroy
    @user&.destroy
  end

  test "purges unattached blobs older than the retention window" do
    stale = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("orphan audio"),
      filename: "orphan.mp3",
      content_type: "audio/mpeg",
      service_name: :test
    )
    stale.update_column(:created_at, 2.days.ago)

    fresh = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("recent orphan"),
      filename: "fresh.mp3",
      content_type: "audio/mpeg",
      service_name: :test
    )
    fresh.update_column(:created_at, 12.hours.ago)

    attached = @workspace.recording_sessions.create!(
      creator: @user,
      title: "Attached",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    assert_enqueued_jobs 1, only: ActiveStorage::PurgeJob do
      PurgeUnattachedBlobsJob.perform_now
    end
    perform_enqueued_jobs only: ActiveStorage::PurgeJob

    assert_raises(ActiveRecord::RecordNotFound) { stale.reload }
    assert_nothing_raised { fresh.reload }
    assert_predicate attached.original_audio.blob, :persisted?
  end
end
