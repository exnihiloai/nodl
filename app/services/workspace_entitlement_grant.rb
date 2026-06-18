class WorkspaceEntitlementGrant
  def self.grant!(workspace:, plan_code:, source:, status:, actor: nil, reason: nil, trial: false, stripe_customer_id: nil, stripe_subscription_id: nil, current_period_started_at: nil, current_period_ends_at: nil, usage_period_started_at: nil, usage_period_ends_at: nil)
    BillingCatalog.ensure!
    version = BillingCatalog.active_version!(plan_code)
    now = Time.current
    trial_started_at = trial ? now : nil
    trial_ends_at = trial ? 14.days.from_now : nil

    WorkspaceEntitlement.find_or_initialize_by(workspace:).tap do |entitlement|
      entitlement.billing_plan_version = version
      entitlement.source = source
      entitlement.status = status
      entitlement.limits_snapshot = version.limits.deep_dup
      entitlement.stripe_customer_id = stripe_customer_id
      entitlement.stripe_subscription_id = stripe_subscription_id
      entitlement.trial_started_at = trial_started_at
      entitlement.trial_ends_at = trial_ends_at
      entitlement.current_period_started_at = current_period_started_at
      entitlement.current_period_ends_at = current_period_ends_at
      entitlement.usage_period_started_at = usage_period_started_at || default_usage_period_started_at(plan_code, current_period_started_at)
      entitlement.usage_period_ends_at = usage_period_ends_at || default_usage_period_ends_at(plan_code, entitlement.usage_period_started_at)
      entitlement.metadata = entitlement.metadata.merge("reason" => reason).compact
      entitlement.save!
      workspace.association(:current_entitlement).reset
    end
  end

  def self.default_usage_period_started_at(plan_code, current_period_started_at)
    return unless plan_code.in?(%w[starter business])

    current_period_started_at || Time.current
  end
  private_class_method :default_usage_period_started_at

  def self.default_usage_period_ends_at(plan_code, usage_period_started_at)
    return unless plan_code.in?(%w[starter business])
    return unless usage_period_started_at

    usage_period_started_at + 1.month
  end
  private_class_method :default_usage_period_ends_at
end
