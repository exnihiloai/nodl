require "test_helper"

class SessionsSecurityIntegrationTest < ActionDispatch::IntegrationTest
  def create_user_with_workspace(email:, password: "Valid123", active: true)
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      role: :user,
      active: active
    )

    workspace = Workspace.create!(
      name: "#{email.split("@").first.titleize} Workspace",
      usage_limits: { scans: 1000, storage_mb: 1024 },
      usage_consumption: { scans: 0, storage_mb: 0 }
    )

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
