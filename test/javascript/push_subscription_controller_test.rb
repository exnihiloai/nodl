require "test_helper"

class PushSubscriptionControllerTest < ActiveSupport::TestCase
  CONTROLLER_PATH = Rails.root.join("app/javascript/controllers/push_subscription_controller.js")

  test "enabled reminder flow persists an existing browser subscription" do
    source = CONTROLLER_PATH.read

    assert_includes source, "await this.persistSubscription(subscription)"
    assert_not_includes source, "hasRegisteredSubscription"
  end
end
