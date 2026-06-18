require "test_helper"

class EntitlementPolicyTest < ActiveSupport::TestCase
  test "new workspaces default to trial entitlement" do
    workspace = Workspace.create!(name: "Trial Workspace")

    entitlement = workspace.reload.current_entitlement
    assert_equal "trial", entitlement.plan_code
    assert_equal "trial", entitlement.source
    assert_equal "trialing", entitlement.status
    assert_in_delta 14.days.from_now.to_i, entitlement.trial_ends_at.to_i, 5
  end

  test "deleting recordings does not reduce trial usage" do
    user = create_user_with_workspace
    workspace = user.workspaces.first
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Exercise append-only usage"
    )

    recordings = 3.times.map do |index|
      workspace.recording_sessions.create!(
        creator: user,
        title: "Recording #{index}",
        transformer_handle: "default",
        status: :completed
      ) { |session| attach_sample_audio(session) }
    end

    recordings.first.destroy!

    assert workspace.reload.recording_limit_reached?
    assert_equal 3, workspace.usage_events.where(event_kind: "recording_created").count
  end

  test "workspace entitlement keeps old snapshot when a later plan version changes limits" do
    plan = BillingPlan.find_or_create_by!(code: "business") do |record|
      record.display_name = "Business"
      record.stripe_required = true
    end
    old_version = plan.billing_plan_versions.create!(
      version_key: "business_test_old",
      status: "active",
      stripe_price_id: "price_business_old",
      limits: { "recordings" => { "type" => "count", "limit" => 100, "period" => "billing_period", "unit" => "count" } }
    )
    plan.billing_plan_versions.create!(
      version_key: "business_test_new",
      status: "active",
      stripe_price_id: "price_business_new",
      limits: { "recordings" => { "type" => "count", "limit" => 50, "period" => "billing_period", "unit" => "count" } }
    )
    workspace = create_user_with_workspace.workspaces.first

    entitlement = workspace.current_entitlement
    entitlement.update!(
      billing_plan_version: old_version,
      source: "stripe",
      status: "active",
      limits_snapshot: old_version.limits.deep_dup,
      stripe_customer_id: "cus_test_old",
      stripe_subscription_id: "sub_test_old",
      current_period_started_at: Time.current.beginning_of_month,
      current_period_ends_at: Time.current.next_month.beginning_of_month
    )

    assert_equal 100, entitlement.reload.limits_snapshot.dig("recordings", "limit")
  end

  test "quantity limits sum usage event quantities inside the configured period" do
    workspace = create_user_with_workspace.workspaces.first
    entitlement = workspace.current_entitlement
    entitlement.update!(
      limits_snapshot: entitlement.limits_snapshot.merge(
        "recorded_audio_seconds" => { "type" => "quantity", "limit" => 3600, "period" => "week", "unit" => "seconds" }
      )
    )
    UsageRecorder.record!(workspace:, event_kind: "recorded_audio_seconds", quantity: 1800, unit: "seconds")
    UsageRecorder.record!(workspace:, event_kind: "recorded_audio_seconds", quantity: 1800, unit: "seconds")

    result = EntitlementPolicy.new(workspace).allowed?(:recorded_audio_seconds, quantity: 1, unit: "seconds")

    assert_predicate result, :denied?
    assert_equal :limit_reached, result.reason
    assert_equal 3600, result.usage
  end

  test "per-action limits are checked against candidate quantity" do
    workspace = create_user_with_workspace.workspaces.first
    result = EntitlementPolicy.new(workspace).allowed?(:max_recording_duration_seconds, quantity: PlanLimits.max_recording_duration_seconds + 1, unit: "seconds")

    assert_predicate result, :denied?
    assert_equal :limit_reached, result.reason
  end

  test "manual private access remains active without stripe state" do
    workspace = create_user_with_workspace.workspaces.first
    entitlement = workspace.current_entitlement

    assert_equal "manual", entitlement.plan_code
    assert_nil entitlement.stripe_customer_id
    assert_nil entitlement.stripe_subscription_id
    assert entitlement.active_for_access?
  end
end
