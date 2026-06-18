require "test_helper"

class PaymentsAnonymousCheckoutTest < ActionDispatch::IntegrationTest
  def with_env(overrides)
    old = {}
    overrides.each do |key, value|
      old[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    overrides.each_key do |key|
      old[key].nil? ? ENV.delete(key) : ENV[key] = old[key]
    end
  end

  test "anonymous checkout redirects directly to stripe and lets checkout collect email" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.test/session/cs_test_anonymous")
    captured = nil

    with_env(
      "STRIPE_SECRET_KEY" => "sk_test_123",
      "STRIPE_STARTER_PRICE_ID_USD" => "price_starter_usd_monthly"
    ) do
      Stripe::Checkout::Session.stubs(:create).with do |params|
        captured = params
        true
      end.returns(fake_session)

      post payments_checkout_path, params: { plan: "starter", region: "international", interval: "monthly" }
    end

    assert_equal 303, response.status
    assert_equal fake_session.url, response.headers["Location"]
    assert_equal "subscription", captured[:mode]
    assert_equal [ { price: "price_starter_usd_monthly", quantity: 1 } ], captured[:line_items]
    assert_nil captured[:customer_email]
    assert_nil captured[:client_reference_id]
    refute captured[:metadata].key?(:user_id)
    refute captured[:metadata].key?(:workspace_id)
    assert_equal "starter", captured[:metadata][:plan_code]
    assert_equal "monthly", captured[:metadata][:billing_interval]
  end

  test "success provisions anonymous checkout account and logs user in" do
    BillingCatalog.ensure!
    plan_version = BillingCatalog.active_version!("starter")
    session_obj = checkout_session(
      email: "new-checkout@example.test",
      plan_version:,
      customer: "cus_test_checkout",
      subscription: "sub_test_checkout"
    )

    with_env("STRIPE_SECRET_KEY" => "sk_test_123") do
      Stripe::Checkout::Session.stubs(:retrieve).with("cs_test_success").returns(session_obj)
      get payments_success_path(session_id: "cs_test_success")
    end

    assert_redirected_to dashboard_path
    assert_equal "Your account is ready.", flash[:notice]

    user = User.find_by!(email: "new-checkout@example.test")
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Dashboard"
    assert_equal user.id, session[:user_id]

    workspace = user.workspaces.first
    entitlement = workspace.current_entitlement
    assert_equal "starter", entitlement.plan_code
    assert_equal "stripe", entitlement.source
    assert_equal "active", entitlement.status
    assert_equal "cus_test_checkout", entitlement.stripe_customer_id
    assert_equal "sub_test_checkout", entitlement.stripe_subscription_id
  end

  test "success reuses existing checkout account by email" do
    BillingCatalog.ensure!
    user = create_user_with_workspace(email: "existing-checkout@example.test")
    workspace = user.workspaces.first
    plan_version = BillingCatalog.active_version!("business")
    session_obj = checkout_session(
      email: "existing-checkout@example.test",
      plan_version:,
      plan_code: "business",
      customer: "cus_existing_checkout",
      subscription: "sub_existing_checkout"
    )

    with_env("STRIPE_SECRET_KEY" => "sk_test_123") do
      Stripe::Checkout::Session.stubs(:retrieve).with("cs_test_existing").returns(session_obj)
      assert_no_difference -> { User.count } do
        assert_no_difference -> { Workspace.count } do
          get payments_success_path(session_id: "cs_test_existing")
        end
      end
    end

    assert_redirected_to dashboard_path
    assert_equal user.id, session[:user_id]
    assert_equal workspace.id, session[:current_workspace_id]
    assert_equal "business", workspace.reload.current_entitlement.plan_code
  end

  test "success does not provision account for incomplete checkout session" do
    BillingCatalog.ensure!
    plan_version = BillingCatalog.active_version!("starter")
    session_obj = checkout_session(
      email: "open-checkout@example.test",
      plan_version:,
      status: "open",
      payment_status: "unpaid"
    )

    with_env("STRIPE_SECRET_KEY" => "sk_test_123") do
      Stripe::Checkout::Session.stubs(:retrieve).with("cs_test_open").returns(session_obj)
      assert_no_difference -> { User.count } do
        get payments_success_path(session_id: "cs_test_open")
      end
    end

    assert_redirected_to payments_cancel_path(reason: "checkout_failed")
    assert_equal "Unable to start checkout right now.", flash[:alert]
  end

  private

  def checkout_session(email:, plan_version:, plan_code: "starter", customer: nil, subscription: nil, status: "complete", payment_status: "paid")
    Struct.new(:metadata, :customer_details, :customer, :subscription, :status, :payment_status, keyword_init: true).new(
      metadata: {
        "plan_version_id" => plan_version.id.to_s,
        "plan_code" => plan_code,
        "billing_region" => "eu",
        "billing_interval" => "annual",
        "currency" => "eur",
        "amount_cents" => "29000"
      },
      customer_details: Struct.new(:email).new(email),
      customer: customer,
      subscription: subscription,
      status: status,
      payment_status: payment_status
    )
  end
end
