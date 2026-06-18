require "application_system_test_case"

class PaymentsSystemTest < ApplicationSystemTestCase
  test "payments page shows stripe setup instructions when not configured" do
    without_stripe_secret_key do
      visit payments_path
    end

    assert_text I18n.t("payments.show.heading")
    assert_text "Checkout not available yet"
    assert_text "STRIPE_SECRET_KEY"
    assert_text "Starter"
    assert_text "Business"
  end

  test "cancel page can retry checkout and redirects back with alert" do
    email = unique_email("payments-cancel")
    create_user_with_workspace(email: email, password: "Valid123")
    login_via_ui(email: email, password: "Valid123")

    without_stripe_secret_key do
      visit payments_cancel_path(reason: "checkout_failed")

      click_button "Try again"
    end

    assert_current_path payments_cancel_path(reason: "checkout_failed"), ignore_query: false
    assert_text "Stripe is not configured. Set STRIPE_SECRET_KEY first."
  end

  test "success page fails closed without stripe configuration" do
    without_stripe_secret_key do
      visit payments_success_path(session_id: "cs_test_123")
    end

    assert_current_path payments_cancel_path(reason: "checkout_failed"), ignore_query: false
    assert_text "Unable to start checkout right now."
  end

  private

  def without_stripe_secret_key
    old_secret_key = ENV["STRIPE_SECRET_KEY"]
    ENV.delete("STRIPE_SECRET_KEY")
    yield
  ensure
    old_secret_key.nil? ? ENV.delete("STRIPE_SECRET_KEY") : ENV["STRIPE_SECRET_KEY"] = old_secret_key
  end
end
