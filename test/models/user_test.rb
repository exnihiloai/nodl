require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "google provider uid pair must be unique" do
    User.create!(
      email: unique_email("google-primary"),
      password: "Valid123",
      password_confirmation: "Valid123",
      provider: "google_oauth2",
      uid: "google-uid-123"
    )

    duplicate = User.new(
      email: unique_email("google-duplicate"),
      password: "Valid123",
      password_confirmation: "Valid123",
      provider: "google_oauth2",
      uid: "google-uid-123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uid], "has already been taken"
  end

  test "daily reminder requires timezone and time when enabled" do
    user = create_user_with_workspace
    user.daily_reminder_enabled = true

    assert_not user.valid?
    assert_includes user.errors[:time_zone], "can't be blank"
    assert_includes user.errors[:daily_reminder_at], "can't be blank"
  end

  test "daily reminder message is limited to 30 characters" do
    user = create_user_with_workspace
    user.assign_attributes(
      daily_reminder_enabled: true,
      time_zone: "Europe/Vienna",
      daily_reminder_at: "21:00",
      daily_reminder_message: "a" * 31
    )

    assert_not user.valid?
    assert_includes user.errors[:daily_reminder_message], "is too long (maximum is 30 characters)"
  end

  test "daily reminder message text falls back to locale default" do
    user = create_user_with_workspace
    user.preferred_language = "de"
    user.daily_reminder_message = nil

    assert_equal "Heute schon genodelt?", user.daily_reminder_message_text
  end

  test "nodled today checks finalized sessions in user timezone" do
    user = create_user_with_workspace
    user.update!(time_zone: "UTC")

    workspace = user.workspaces.first
    travel_to Time.utc(2026, 6, 14, 10, 0, 0) do
      session = workspace.recording_sessions.create!(
        creator: user,
        title: "Morning note",
        transformer_handle: "default",
        status: :completed,
        time_zone: "UTC"
      ) { |recording| attach_sample_audio(recording) }

      assert user.nodled_today?

      session.update!(status: :recording)
      assert_not user.nodled_today?
    end
  end

  test "reminder due at matches local wall clock" do
    user = create_user_with_workspace
    user.update!(
      daily_reminder_enabled: true,
      time_zone: "Europe/Vienna",
      daily_reminder_at: "21:00"
    )

    due_at = ActiveSupport::TimeZone["Europe/Vienna"].local(2026, 6, 14, 21, 0, 0)
    not_due_at = ActiveSupport::TimeZone["Europe/Vienna"].local(2026, 6, 14, 20, 45, 0)

    assert user.reminder_due_at?(now: due_at)
    assert_not user.reminder_due_at?(now: not_due_at)
  end
end
