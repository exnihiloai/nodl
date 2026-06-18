require "test_helper"

class BillingPlanVersionTest < ActiveSupport::TestCase
  test "active plan version limits are immutable" do
    plan = BillingPlan.find_or_create_by!(code: "manual") do |record|
      record.display_name = "Private Access"
      record.stripe_required = false
    end
    version = plan.billing_plan_versions.create!(
      version_key: "manual_immutable_test",
      status: "active",
      limits: { "recordings" => { "type" => "unlimited", "limit" => "unlimited" } }
    )

    version.limits = { "recordings" => { "type" => "count", "limit" => 1, "period" => "lifetime", "unit" => "count" } }

    assert_not version.valid?
    assert_includes version.errors[:limits], "cannot be changed after a plan version is active or retired"
  end
end
