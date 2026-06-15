require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user_with_workspace
    post login_path, params: { email: @user.email, password: "Valid123" }
    @subscription_params = {
      endpoint: "https://push.example.test/device/abc",
      p256dh_key: "p256dh-key",
      auth_key: "auth-key"
    }
  end

  teardown do
    @user&.destroy
  end

  test "creates a push subscription for the current user" do
    assert_difference -> { @user.push_subscriptions.count }, 1 do
      post push_subscriptions_path, params: { push_subscription: @subscription_params }, as: :json
    end

    assert_response :created
  end

  test "upserts an existing push subscription endpoint" do
    @user.push_subscriptions.create!(@subscription_params)

    assert_no_difference -> { PushSubscription.count } do
      post push_subscriptions_path,
           params: { push_subscription: @subscription_params.merge(p256dh_key: "updated-key") },
           as: :json
    end

    assert_response :created
    assert_equal "updated-key", @user.push_subscriptions.find_by!(endpoint: @subscription_params[:endpoint]).p256dh_key
  end

  test "reassigns a browser endpoint from another user to the current user" do
    other = create_user_with_workspace
    other.push_subscriptions.create!(@subscription_params)

    assert_difference -> { @user.push_subscriptions.count }, 1 do
      assert_difference -> { other.push_subscriptions.count }, -1 do
        post push_subscriptions_path, params: { push_subscription: @subscription_params }, as: :json
      end
    end

    assert_response :created
    assert_equal @user.id, PushSubscription.find_by!(endpoint: @subscription_params[:endpoint]).user_id
  ensure
    other.push_subscriptions.destroy_all
    other&.destroy
  end

  test "destroys the current user subscription by endpoint" do
    subscription = @user.push_subscriptions.create!(@subscription_params)

    assert_difference -> { PushSubscription.count }, -1 do
      delete push_subscription_path(subscription, params: { endpoint: subscription.endpoint })
    end

    assert_response :no_content
  end

  test "cannot destroy another users subscription" do
    other = create_user_with_workspace
    subscription = other.push_subscriptions.create!(@subscription_params.merge(endpoint: "https://push.example.test/other"))

    assert_no_difference -> { PushSubscription.count } do
      delete push_subscription_path(subscription, params: { endpoint: subscription.endpoint })
      assert_response :not_found
    end
  ensure
    other.push_subscriptions.destroy_all
    other&.destroy
  end
end
