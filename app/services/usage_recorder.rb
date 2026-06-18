class UsageRecorder
  CAPABILITY_EVENT_KINDS = EntitlementPolicy::CAPABILITY_EVENTS.invert.freeze

  def self.record!(workspace:, event_kind:, user: nil, quantity: 1, unit: "count", subject: nil, metadata: {}, occurred_at: Time.current)
    entitlement = workspace.current_entitlement
    entitlement&.ensure_current_usage_period!(now: occurred_at)
    UsageEvent.create!(
      workspace:,
      user:,
      event_kind:,
      quantity:,
      unit:,
      subject_type: subject&.class&.name,
      subject_id: subject&.id,
      metadata:,
      occurred_at:,
      billing_period_started_at: entitlement&.current_period_started_at,
      billing_period_ends_at: entitlement&.current_period_ends_at,
      usage_period_started_at: entitlement&.usage_period_started_at,
      usage_period_ends_at: entitlement&.usage_period_ends_at
    )
  end
end
