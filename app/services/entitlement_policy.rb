class EntitlementPolicy
  CAPABILITY_EVENTS = {
    "recordings" => "recording_created",
    "custom_formats" => "custom_format_created",
    "exports" => "document_exported",
    "original_audio_downloads" => "original_audio_downloaded",
    "integrity_checks" => "integrity_check_attempted",
    "recorded_audio_seconds" => "recorded_audio_seconds"
  }.freeze

  Result = Struct.new(:allowed, :reason, :usage, :limit, :capability, :upgrade_target, keyword_init: true) do
    alias_method :allowed?, :allowed

    def denied?
      !allowed?
    end
  end

  def initialize(workspace, now: Time.current)
    @workspace = workspace
    @now = now
  end

  def allowed?(capability, quantity: 1, unit: "count", subject: nil)
    capability = capability.to_s
    entitlement = workspace.current_entitlement
    return denied(capability, :missing_entitlement) unless entitlement
    return denied(capability, :inactive_entitlement) unless entitlement.active_for_access?(now:)

    definition = entitlement.limits_snapshot.fetch(capability, nil)
    return denied(capability, :not_included) unless definition

    case definition.fetch("type")
    when "unlimited"
      allowed(capability, usage: nil, limit: "unlimited")
    when "boolean"
      definition["limit"] ? allowed(capability, usage: nil, limit: true) : denied(capability, :not_included, limit: false)
    when "per_action"
      check_per_action(capability, definition, quantity)
    when "count", "quantity"
      check_metered(capability, definition, quantity, unit)
    else
      denied(capability, :unknown_limit_type)
    end
  end

  private

  attr_reader :workspace, :now

  def check_per_action(capability, definition, quantity)
    limit = numeric_limit(definition)
    return allowed(capability, usage: quantity, limit:) if quantity.to_d <= limit.to_d

    denied(capability, :limit_reached, usage: quantity, limit:)
  end

  def check_metered(capability, definition, quantity, unit)
    limit = numeric_limit(definition)
    consumed = consumed_for(capability, definition, unit)
    projected = consumed + quantity.to_d
    return allowed(capability, usage: consumed, limit:) if projected <= limit.to_d

    denied(capability, :limit_reached, usage: consumed, limit:)
  end

  def consumed_for(capability, definition, unit)
    event_kind = CAPABILITY_EVENTS.fetch(capability)
    scope = workspace.usage_events.where(event_kind:, unit:)
    scope = apply_period(scope, definition.fetch("period", "lifetime"))
    scope.sum(:quantity)
  end

  def apply_period(scope, period)
    case period
    when "lifetime"
      scope
    when "billing_period"
      entitlement = workspace.current_entitlement
      return scope.none unless entitlement&.current_period_started_at && entitlement&.current_period_ends_at

      scope.where(occurred_at: entitlement.current_period_started_at...entitlement.current_period_ends_at)
    when "week"
      scope.where(occurred_at: now.beginning_of_week...now.end_of_week)
    when "day"
      scope.where(occurred_at: now.beginning_of_day...now.end_of_day)
    else
      scope
    end
  end

  def numeric_limit(definition)
    raw_limit = definition.fetch("limit")
    return raw_limit if raw_limit.is_a?(Numeric)
    return raw_limit.to_i if raw_limit.to_s.match?(/\A\d+\z/)

    BigDecimal(raw_limit.to_s)
  end

  def allowed(capability, usage:, limit:)
    Result.new(allowed: true, reason: nil, usage:, limit:, capability:, upgrade_target: nil)
  end

  def denied(capability, reason, usage: nil, limit: nil)
    Result.new(allowed: false, reason:, usage:, limit:, capability:, upgrade_target: "starter")
  end
end
