class BillingPlanVersion < ApplicationRecord
  STATUSES = %w[draft active retired].freeze

  belongs_to :billing_plan
  has_many :workspace_entitlements, dependent: :restrict_with_exception

  normalizes :version_key, with: ->(key) { key.to_s.strip }
  normalizes :status, with: ->(status) { status.to_s.strip.downcase }
  normalizes :stripe_price_id, with: ->(price_id) { price_id.to_s.strip.presence }

  validates :version_key, presence: true, uniqueness: true
  validates :stripe_price_id, uniqueness: true, allow_nil: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :limits, presence: true
  validate :immutable_limits_after_activation, on: :update

  scope :active, -> { where(status: "active") }

  def paid?
    billing_plan.code.in?(%w[starter business])
  end

  private

  def immutable_limits_after_activation
    return unless will_save_change_to_limits?
    return if status_was == "draft"

    errors.add(:limits, "cannot be changed after a plan version is active or retired")
  end
end
