require "test_helper"
require "time"

class SessionsSecurityIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def create_user_with_workspace(email:, password: "Valid123", active: true)
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      role: :user,
      active: active
    )

    workspace = Workspace.create!(name: "#{email.split("@").first.titleize} Workspace")

    Membership.create!(user: user, workspace: workspace, role: :owner)
    user
  end

  def with_memory_cache
    old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = old_cache
  end

  test "deactivated user gets generic invalid credentials message" do
    user = create_user_with_workspace(email: "inactive-security@example.test", active: false)

    post login_path, params: { email: user.email, password: "Valid123" }

    assert_response :unprocessable_entity
    assert_includes response.body, "Invalid credentials."
    refute_includes response.body, "deactivated"
  end

  test "login persists the session cookie for one year" do
    user = create_user_with_workspace(email: "persistent-session@example.test")

    travel_to Time.zone.local(2026, 6, 13, 12, 0, 0) do
      post login_path, params: { email: user.email, password: "Valid123" }
    end

    session_cookie = response.headers.fetch("Set-Cookie").split("\n").find { |cookie| cookie.start_with?("_nodl_session=") }
    assert session_cookie, "login must set the _nodl_session cookie"

    expires_attribute = session_cookie.split(";").map(&:strip).find { |attribute| attribute.start_with?("expires=") }
    assert expires_attribute, "login must set a persistent session cookie; configure expire_after: 1.year in config/initializers/session_store.rb"

    assert_equal Time.utc(2027, 6, 13, 12, 0, 0), Time.httpdate(expires_attribute.delete_prefix("expires="))
  end

  test "login endpoint throttles repeated failed attempts" do
    user = create_user_with_workspace(email: "throttle-security@example.test")

    with_memory_cache do
      9.times do
        post login_path, params: { email: user.email, password: "wrong-password" }
        assert_response :unprocessable_entity
      end

      post login_path, params: { email: user.email, password: "wrong-password" }
      assert_response :too_many_requests

      post login_path, params: { email: user.email, password: "wrong-password" }
      assert_response :too_many_requests
      assert_includes response.body, "Invalid credentials."
    end
  end
end
