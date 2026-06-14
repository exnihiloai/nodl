require "test_helper"

class DispatchDailyRemindersJobTest < ActiveJob::TestCase
  setup do
    @user = create_user_with_workspace
    @user.update!(
      daily_reminder_enabled: true,
      time_zone: "UTC",
      daily_reminder_at: "21:00"
    )
    @user.push_subscriptions.create!(
      endpoint: "https://push.example.test/device/#{SecureRandom.hex(4)}",
      p256dh_key: "p256dh",
      auth_key: "auth"
    )
  end

  teardown do
    @user.push_subscriptions.destroy_all
    @user.created_recording_sessions.destroy_all
    @user&.destroy
  end

  test "enqueues send job when reminder is due and user has not nodled today" do
    due_at = Time.utc(2026, 6, 14, 21, 0, 0)

    assert_enqueued_with(job: SendDailyReminderPushJob, args: [ @user.id, due_at.iso8601 ]) do
      DispatchDailyRemindersJob.perform_now(now: due_at)
    end
  end

  test "skips users who already nodled today" do
    workspace = @user.workspaces.first
    due_at = Time.utc(2026, 6, 14, 21, 0, 0)

    workspace.recording_sessions.create!(
      creator: @user,
      title: "Done",
      transformer_handle: "default",
      status: :completed,
      time_zone: "UTC"
    ) { |recording| attach_sample_audio(recording) }

    assert_no_enqueued_jobs(only: SendDailyReminderPushJob) do
      DispatchDailyRemindersJob.perform_now(now: due_at)
    end
  end

  test "skips users who already received a reminder today" do
    due_at = Time.utc(2026, 6, 14, 21, 0, 0)
    @user.update!(daily_reminder_last_sent_on: due_at.to_date)

    assert_no_enqueued_jobs(only: SendDailyReminderPushJob) do
      DispatchDailyRemindersJob.perform_now(now: due_at)
    end
  end
end
