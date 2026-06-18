class BillingCatalog
  CURRENT_VERSION_SUFFIX = "2026_06_v1".freeze

  PLAN_DEFINITIONS = {
    "manual" => { display_name: "Private Access", stripe_required: false },
    "trial" => { display_name: "Free Trial", stripe_required: false },
    "starter" => { display_name: "Starter", stripe_required: true },
    "business" => { display_name: "Business", stripe_required: true }
  }.freeze

  LIMITS = {
    "manual" => {
      "recordings" => { "type" => "unlimited", "limit" => "unlimited" },
      "custom_formats" => { "type" => "unlimited", "limit" => "unlimited" },
      "exports" => { "type" => "unlimited", "limit" => "unlimited" },
      "original_audio_downloads" => { "type" => "unlimited", "limit" => "unlimited" },
      "integrity_checks" => { "type" => "boolean", "limit" => true },
      "max_recording_duration_seconds" => { "type" => "per_action", "limit" => PlanLimits.max_recording_duration_seconds, "period" => "per_action", "unit" => "seconds" }
    },
    "trial" => {
      "recordings" => { "type" => "count", "limit" => 3, "period" => "lifetime", "unit" => "count" },
      "custom_formats" => { "type" => "count", "limit" => 2, "period" => "lifetime", "unit" => "count" },
      "exports" => { "type" => "count", "limit" => 1, "period" => "lifetime", "unit" => "count" },
      "original_audio_downloads" => { "type" => "count", "limit" => 1, "period" => "lifetime", "unit" => "count" },
      "integrity_checks" => { "type" => "boolean", "limit" => false },
      "max_recording_duration_seconds" => { "type" => "per_action", "limit" => PlanLimits.max_recording_duration_seconds, "period" => "per_action", "unit" => "seconds" }
    },
    "starter" => {
      "recordings" => { "type" => "count", "limit" => 500, "period" => "usage_period", "unit" => "count" },
      "recorded_audio_seconds" => { "type" => "quantity", "limit" => 100.hours.to_i, "period" => "usage_period", "unit" => "seconds" },
      "custom_formats" => { "type" => "count", "limit" => 10, "period" => "lifetime", "unit" => "count" },
      "exports" => { "type" => "unlimited", "limit" => "unlimited" },
      "original_audio_downloads" => { "type" => "unlimited", "limit" => "unlimited" },
      "integrity_checks" => { "type" => "boolean", "limit" => false },
      "max_recording_duration_seconds" => { "type" => "per_action", "limit" => PlanLimits.max_recording_duration_seconds, "period" => "per_action", "unit" => "seconds" }
    },
    "business" => {
      "recordings" => { "type" => "count", "limit" => 2000, "period" => "usage_period", "unit" => "count" },
      "recorded_audio_seconds" => { "type" => "quantity", "limit" => 500.hours.to_i, "period" => "usage_period", "unit" => "seconds" },
      "custom_formats" => { "type" => "unlimited", "limit" => "unlimited" },
      "exports" => { "type" => "unlimited", "limit" => "unlimited" },
      "original_audio_downloads" => { "type" => "unlimited", "limit" => "unlimited" },
      "integrity_checks" => { "type" => "boolean", "limit" => true },
      "max_recording_duration_seconds" => { "type" => "per_action", "limit" => PlanLimits.max_recording_duration_seconds, "period" => "per_action", "unit" => "seconds" }
    }
  }.freeze

  def self.ensure!
    new.ensure!
  end

  def ensure!
    PLAN_DEFINITIONS.each do |code, attributes|
      plan = BillingPlan.find_or_create_by!(code:) do |record|
        record.display_name = attributes.fetch(:display_name)
        record.stripe_required = attributes.fetch(:stripe_required)
      end
      plan.update!(display_name: attributes.fetch(:display_name), stripe_required: attributes.fetch(:stripe_required)) if plan.persisted?

      version_key = "#{code}_#{CURRENT_VERSION_SUFFIX}"
      BillingPlanVersion.find_or_create_by!(version_key:) do |version|
        version.billing_plan = plan
        version.status = active_status_for(code)
        version.limits = LIMITS.fetch(code)
        version.active_from = Time.current if version.status == "active"
      end.tap do |version|
        version.update!(status: "active", active_from: Time.current) if version.status == "draft"
      end
    end
  end

  def self.active_version!(code)
    ensure!
    BillingPlan.find_by!(code:).billing_plan_versions.active.order(active_from: :desc, created_at: :desc).first!
  end

  private

  def active_status_for(code)
    "active"
  end
end
