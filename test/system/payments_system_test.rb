require "application_system_test_case"

class PaymentsSystemTest < ApplicationSystemTestCase
  test "payments page shows stripe setup instructions when not configured" do
    visit payments_path

    assert_text "Payments preview"
    assert_text "Stripe configuration required"
    assert_text "STRIPE_SECRET_KEY"
  end

  test "cancel page can retry checkout and redirects back with alert" do
    email = unique_email("payments-cancel")
    create_user_with_workspace(email: email, password: "Valid123")
    login_via_ui(email: email, password: "Valid123")

    visit payments_cancel_path

    click_button "Try again"

    assert_current_path payments_path, ignore_query: true
    assert_text "Stripe is not configured. Set STRIPE_SECRET_KEY first."
  end

  test "success page renders passed session id" do
    email = unique_email("payments-success")
    create_user_with_workspace(email: email, password: "Valid123")
    login_via_ui(email: email, password: "Valid123")

    visit payments_success_path(session_id: "cs_test_123")

    assert_text "Payment confirmed"
    assert_text "cs_test_123"
  end
end
