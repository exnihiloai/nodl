require "test_helper"

class AdminIntegritySealingTest < ActionDispatch::IntegrationTest
  test "admin toggles integrity sealing and writes audit event" do
    admin = create_user_with_workspace(email: "admin-integrity@example.test", role: :admin)
    user = create_user_with_workspace(email: "managed-integrity@example.test")
    login(admin)

    assert_difference -> { AdminAuditEvent.where(action: "update_integrity_sealing").count }, 1 do
      patch update_integrity_sealing_admin_user_path(user), params: { integrity_sealing_enabled: "1" }
    end

    assert_redirected_to admin_user_path(user)
    assert user.reload.integrity_sealing_enabled?
    audit = AdminAuditEvent.where(action: "update_integrity_sealing").last
    assert_equal({ "integrity_sealing_enabled" => false }, audit.before_state)
    assert_equal({ "integrity_sealing_enabled" => true }, audit.after_state)
  end

  test "ordinary user cannot toggle integrity sealing" do
    user = create_user_with_workspace(email: "ordinary-integrity@example.test")
    other = create_user_with_workspace(email: "target-integrity@example.test")
    login(user)

    patch update_integrity_sealing_admin_user_path(other), params: { integrity_sealing_enabled: "1" }

    assert_redirected_to dashboard_path
    assert_not other.reload.integrity_sealing_enabled?
  end

  private

  def login(user)
    post login_path, params: { email: user.email, password: "Valid123" }
  end
end
