ENV["RAILS_ENV"] ||= "test"

# Opt-in coverage map: `COVERAGE=1 bin/rails test`. Must start before the app
# loads so all application code is instrumented. Off by default to keep normal
# runs fast.
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
    add_filter "/test/"
  end
end

require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "tmpdir"

module ActiveSupport
  class TestCase
    SEMVER_PATTERN = /\A\d+\.\d+\.\d+\z/

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Each parallel worker is a separate process, so it needs its own coverage
    # command name; results are merged when every worker reports.
    if ENV["COVERAGE"]
      parallelize_setup do |worker|
        SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
      end

      parallelize_teardown do |_worker|
        SimpleCov.result
      end
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def unique_email(prefix = "user")
      "#{prefix}-#{SecureRandom.hex(4)}@example.test"
    end

    def assert_valid_semver(version, message = nil)
      assert_predicate version, :present?, message || "expected a version number"
      assert_match SEMVER_PATTERN, version, message || "expected #{version.inspect} to match semver (major.minor.patch)"
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

    def with_private_view_root(path)
      original = PrivateContent.view_root
      PrivateContent.view_root = Pathname.new(path)
      yield
    ensure
      PrivateContent.view_root = original
    end

    def with_private_about_page
      Dir.mktmpdir do |dir|
        view_root = Pathname.new(dir).join("views")
        pages = view_root.join("pages")
        pages.mkpath
        pages.join("about.html.erb").write(<<~ERB)
          <section>
            <h1>Private about fixture</h1>
            <%= link_to "Changelog", changelog_path, data: { testid: "about-changelog-link" } %>
            <%= link_to "Licenses", licenses_path, data: { testid: "about-licenses-link" } %>
          </section>
        ERB

        with_private_view_root(view_root) { yield }
      end
    end
  end
end
