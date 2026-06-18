class WorkspaceEntitlement < ApplicationRecord
  SOURCES = %w[manual trial stripe].freeze
  STATUSES = %w[active trialing past_due canceled expired revoked].freeze
  GRACE_PERIOD = 14.days

  belongs_to :workspace
  belongs_to :billing_plan_version

  normalizes :source, with: ->(source) { source.to_s.strip.downcase }
  normalizes :status, with: ->(status) { status.to_s.strip.downcase }
  normalizes :stripe_customer_id, with: ->(value) { value.to_s.strip.presence }
  normalizes :stripe_subscription_id, with: ->(value) { value.to_s.strip.presence }

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :workspace_id, uniqueness: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true
  validates :limits_snapshot, presence: true
  validate :manual_access_does_not_require_stripe_state

  delegate :billing_plan, to: :billing_plan_version

  def plan_code
    billing_plan.code
  end

  def display_name
    billing_plan.display_name
  end

  def active_for_access?(now: Time.current)
    return true if status.in?(%w[active trialing])
    return true if status == "past_due" && grace_period_ends_at.present? && grace_period_ends_at.future?
    return true if status == "canceled" && current_period_ends_at.present? && current_period_ends_at.future?

    false
  end

  private

  def manual_access_does_not_require_stripe_state
    return unless source == "manual"
    return if stripe_customer_id.blank? && stripe_subscription_id.blank?

    errors.add(:source, "manual access should not depend on Stripe state")
  end
end
