require "test_helper"

class TelemetryEventsTest < ActionDispatch::IntegrationTest
  test "landing page visit triggers nodl.landing.visited event for guests" do
    events = []
    ActiveSupport::Notifications.subscribe("nodl.landing.visited") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    get root_path
    assert_response :success
    assert_equal 1, events.size
    assert_not_nil events.first.payload[:ip]
  end

  test "landing page visit redirects logged-in users to the dashboard without telemetry" do
    user = create_user_with_workspace
    post login_path, params: { email: user.email, password: "Valid123" }

    events = []
    ActiveSupport::Notifications.subscribe("nodl.landing.visited") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    get root_path
    assert_redirected_to dashboard_path
    assert_empty events
  end

  test "successful registration triggers nodl.user.registered event" do
    events = []
    ActiveSupport::Notifications.subscribe("nodl.user.registered") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    post register_path, params: {
      email: "telemetry-new@example.com",
      email_confirm: "telemetry-new@example.com",
      password: "ValidPassword123",
      password_confirm: "ValidPassword123",
      accept_legal: "1"
    }

    assert_redirected_to dashboard_path
    assert_equal 1, events.size
    assert_equal "telemetry-new@example.com", events.first.payload[:user].email
  end

  test "successful login triggers nodl.user.logged_in event" do
    user = create_user_with_workspace(email: "telemetry-login@example.com")

    events = []
    ActiveSupport::Notifications.subscribe("nodl.user.logged_in") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    post login_path, params: { email: user.email, password: "Valid123" }
    assert_redirected_to dashboard_path
    assert_equal 1, events.size
    assert_equal user.id, events.first.payload[:user].id
  end
end
