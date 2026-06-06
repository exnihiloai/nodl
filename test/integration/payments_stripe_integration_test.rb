require "test_helper"

class PaymentsStripeIntegrationTest < ActionDispatch::IntegrationTest
  def create_user_with_workspace(email: "payments-test@example.test", password: "Valid123")
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      role: :user,
      active: true
    )

    workspace = Workspace.create!(
      name: "#{email.split("@").first.titleize} Workspace",
      usage_limits: { scans: 1000, storage_mb: 1024 },
      usage_consumption: { scans: 0, storage_mb: 0 }
    )

    Membership.create!(user: user, workspace: workspace, role: :owner)
    user
  end

  def login_as(user, password: "Valid123")
    post login_path, params: { email: user.email, password: password }
    assert_redirected_to dashboard_path
  end

  def with_env(overrides)
    old = {}
    overrides.each do |key, value|
      old[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    overrides.each_key do |key|
      if old[key].nil?
        ENV.delete(key)
      else
        ENV[key] = old[key]
      end
    end
  end

  test "payments page shows checkout button when stripe is configured" do
    with_env("STRIPE_SECRET_KEY" => "sk_test_123") do
      get payments_path
      assert_response :success
      assert_includes response.body, "Test checkout"
      refute_includes response.body, "Checkout not available yet"
    end
  end

  test "checkout redirects to stripe hosted session url when configured" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.test/session/cs_test_123")
    captured = nil
    user = create_user_with_workspace(email: "checkout-success@example.test")

    with_env(
      "STRIPE_SECRET_KEY" => "sk_test_123",
      "STRIPE_CURRENCY" => "usd",
      "STRIPE_PRODUCT_NAME" => "Nodl Starter Plan",
      "STRIPE_DEFAULT_AMOUNT" => "1900"
    ) do
      login_as(user)
      Stripe::Checkout::Session.stubs(:create).with do |params|
        captured = params
        true
      end.returns(fake_session)

      post payments_checkout_path
    end

    assert_equal 303, response.status
    assert_equal fake_session.url, response.headers["Location"]
    assert_equal "payment", captured[:mode]
    assert_includes captured[:success_url], "/payments/success"
    assert_includes captured[:cancel_url], "/payments/cancel"
  end

  test "checkout returns to payments with alert if stripe is not configured" do
    user = create_user_with_workspace(email: "checkout-missing-key@example.test")

    with_env("STRIPE_SECRET_KEY" => nil) do
      login_as(user)
      post payments_checkout_path
      assert_redirected_to payments_path
      assert_equal "Stripe is not configured. Set STRIPE_SECRET_KEY first.", flash[:alert]
    end
  end

  test "checkout returns to payments with alert if session url is missing" do
    fake_session = Struct.new(:url).new(nil)
    user = create_user_with_workspace(email: "checkout-missing-url@example.test")

    with_env("STRIPE_SECRET_KEY" => "sk_test_123") do
      login_as(user)
      Stripe::Checkout::Session.stubs(:create).returns(fake_session)
      post payments_checkout_path
    end

    assert_redirected_to payments_path
    assert_equal "Unable to start checkout right now.", flash[:alert]
  end

  test "checkout redirects to login if not authenticated" do
    with_env("STRIPE_SECRET_KEY" => "sk_test_123") do
      post payments_checkout_path
    end

    assert_redirected_to login_path
  end

  test "webhook returns 503 if secret is missing" do
    with_env("STRIPE_WEBHOOK_SECRET" => nil) do
      post payments_webhook_path, params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :service_unavailable
      assert_includes response.body, "Stripe webhook secret not configured"
    end
  end

  test "webhook returns 400 if signature header is missing" do
    with_env("STRIPE_WEBHOOK_SECRET" => "whsec_test") do
      post payments_webhook_path, params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :bad_request
      assert_includes response.body, "Missing Stripe signature header"
    end
  end

  test "webhook returns received true on valid checkout.session.completed event" do
    event = Struct.new(:type, :id, :data).new(
      "checkout.session.completed",
      "evt_test_123",
      Struct.new(:object).new(Struct.new(:id).new("cs_test_123"))
    )

    with_env("STRIPE_WEBHOOK_SECRET" => "whsec_test") do
      Stripe::Webhook.stubs(:construct_event).returns(event)
      post payments_webhook_path,
           params: "{\"id\":\"evt_test_123\"}",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "HTTP_STRIPE_SIGNATURE" => "sig_test"
           }
    end

    assert_response :success
    assert_equal({ "received" => true }, JSON.parse(response.body))
  end

  test "webhook returns 400 on signature verification error" do
    with_env("STRIPE_WEBHOOK_SECRET" => "whsec_test") do
      Stripe::Webhook.stubs(:construct_event).raises(
        Stripe::SignatureVerificationError.new("Invalid signature", "sig", http_body: "{}")
      )
      post payments_webhook_path,
           params: "{}",
           headers: {
             "CONTENT_TYPE" => "application/json",
             "HTTP_STRIPE_SIGNATURE" => "sig_test"
           }
    end

    assert_response :bad_request
    assert_includes response.body, "Invalid signature"
  end
end
