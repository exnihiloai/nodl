ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def unique_email(prefix = "user")
      "#{prefix}-#{SecureRandom.hex(4)}@example.test"
    end

    def create_user_with_workspace(email: unique_email, password: "Valid123", role: :user, active: true, workspace_name: nil)
      user = User.create!(
        email: email,
        password: password,
        password_confirmation: password,
        role: role,
        active: active
      )

      workspace = Workspace.create!(
        name: workspace_name || "#{email.split("@").first.titleize} Workspace",
        usage_limits: { scans: 1000, storage_mb: 1024 },
        usage_consumption: { scans: 0, storage_mb: 0 }
      )

      Membership.create!(user: user, workspace: workspace, role: :owner)
      user
    end

    def attach_sample_audio(recording_session, filename: "sample.mp3", content_type: "audio/mpeg")
      recording_session.original_audio.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3"), "rb"),
        filename: filename,
        content_type: content_type
      )
    end
  end
end
