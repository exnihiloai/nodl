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

    workspace = Workspace.create!(name: "#{email.split("@").first.titleize} Workspace")

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

  test "payments page shows plan overview when stripe is configured" do
    with_env("STRIPE_SECRET_KEY" => "sk_test_123") do
      get payments_path
      assert_response :success
      assert_includes response.body, "Starter"
      assert_includes response.body, "Business"
      assert_includes response.body, "290"
      assert_includes response.body, "Get started"
      assert_select "form[data-turbo='false'][action='#{payments_checkout_path}']", 2
      refute_includes response.body, "Checkout not available yet"
    end
  end

  test "checkout redirects to stripe hosted session url with configured price id" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.test/session/cs_test_123")
    captured = nil
    user = create_user_with_workspace(email: "checkout-success@example.test")

    with_env(
      "STRIPE_SECRET_KEY" => "sk_test_123",
      "STRIPE_STARTER_PRICE_ID_USD" => "price_starter_usd_monthly"
    ) do
      login_as(user)
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
    assert_includes captured[:success_url], "/payments/success"
    assert_includes captured[:cancel_url], "/payments"
    refute_includes captured[:cancel_url], "/payments/cancel"
    assert_equal "starter", captured[:metadata][:plan_code]
    assert_equal "international", captured[:metadata][:billing_region]
    assert_equal "monthly", captured[:metadata][:billing_interval]
  end

  test "checkout can use catalog price data when Stripe Price ID is not configured" do
    fake_session = Struct.new(:url).new("https://checkout.stripe.test/session/cs_test_dynamic")
    captured = nil
    user = create_user_with_workspace(email: "checkout-dynamic-price@example.test")

    with_env(
      "STRIPE_SECRET_KEY" => "sk_test_123",
      "STRIPE_BUSINESS_ANNUAL_PRICE_ID_EUR" => nil,
      "STRIPE_BUSINESS_PRICE_ID_EUR" => nil,
      "STRIPE_BUSINESS_PRICE_ID" => nil
    ) do
      login_as(user)
      Stripe::Checkout::Session.stubs(:create).with do |params|
        captured = params
        true
      end.returns(fake_session)

      post payments_checkout_path, params: { plan: "business", region: "eu", interval: "annual" }
    end

    line_item = captured[:line_items].first
    assert_equal 303, response.status
    assert_equal "eur", line_item[:price_data][:currency]
    assert_equal 99_000, line_item[:price_data][:unit_amount]
    assert_equal({ interval: "year" }, line_item[:price_data][:recurring])
    assert_equal "Business", line_item[:price_data][:product_data][:name]
    assert_equal "annual", captured[:metadata][:billing_interval]
  end

  test "checkout returns to payments with alert if stripe is not configured" do
    user = create_user_with_workspace(email: "checkout-missing-key@example.test")

    with_env("STRIPE_SECRET_KEY" => nil) do
      login_as(user)
      post payments_checkout_path
      assert_redirected_to payments_cancel_path(reason: "checkout_failed")
      assert_equal "Stripe is not configured. Set STRIPE_SECRET_KEY first.", flash[:alert]
    end
  end

  test "checkout returns to cancel page with alert if session url is missing" do
    fake_session = Struct.new(:url).new(nil)
    user = create_user_with_workspace(email: "checkout-missing-url@example.test")

    with_env("STRIPE_SECRET_KEY" => "sk_test_123", "STRIPE_PRICE_ID" => "price_starter_test") do
      login_as(user)
      Stripe::Checkout::Session.stubs(:create).returns(fake_session)
      post payments_checkout_path
    end

    assert_redirected_to payments_cancel_path(reason: "checkout_failed")
    assert_equal "Unable to start checkout right now.", flash[:alert]
  end

  test "cancel page redirects to payments when checkout was not interrupted" do
    user = create_user_with_workspace(email: "cancel-redirect@example.test")
    login_as(user)

    get payments_cancel_path

    assert_redirected_to payments_path
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
