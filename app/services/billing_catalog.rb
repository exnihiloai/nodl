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
      "recordings" => { "type" => "count", "limit" => 500, "period" => "billing_period", "unit" => "count" },
      "recorded_audio_seconds" => { "type" => "quantity", "limit" => 100.hours.to_i, "period" => "billing_period", "unit" => "seconds" },
      "custom_formats" => { "type" => "count", "limit" => 10, "period" => "lifetime", "unit" => "count" },
      "exports" => { "type" => "unlimited", "limit" => "unlimited" },
      "original_audio_downloads" => { "type" => "unlimited", "limit" => "unlimited" },
      "integrity_checks" => { "type" => "boolean", "limit" => false },
      "max_recording_duration_seconds" => { "type" => "per_action", "limit" => PlanLimits.max_recording_duration_seconds, "period" => "per_action", "unit" => "seconds" }
    },
    "business" => {
      "recordings" => { "type" => "count", "limit" => 2000, "period" => "billing_period", "unit" => "count" },
      "recorded_audio_seconds" => { "type" => "quantity", "limit" => 500.hours.to_i, "period" => "billing_period", "unit" => "seconds" },
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
        version.stripe_price_id = stripe_price_id_for(code)
        version.active_from = Time.current if version.status == "active"
      end.tap do |version|
        next unless version.status == "draft"

        price_id = stripe_price_id_for(code)
        next if price_id.blank?

        version.update!(stripe_price_id: price_id, status: "active", active_from: Time.current)
      end
    end
  end

  def self.active_version!(code)
    ensure!
    BillingPlan.find_by!(code:).billing_plan_versions.active.order(active_from: :desc, created_at: :desc).first!
  end

  def self.version_for_stripe_price(price_id)
    ensure!
    BillingPlanVersion.includes(:billing_plan).find_by(stripe_price_id: price_id)
  end

  private

  def active_status_for(code)
    return "draft" if code.in?(%w[starter business]) && stripe_price_id_for(code).blank?

    "active"
  end

  def stripe_price_id_for(code)
    case code
    when "starter"
      ENV["STRIPE_STARTER_PRICE_ID"].presence || ENV["STRIPE_PRICE_ID"].presence
    when "business"
      ENV["STRIPE_BUSINESS_PRICE_ID"].presence
    end
  end
end
