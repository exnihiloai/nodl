class BillingPlan < ApplicationRecord
  CODES = %w[manual trial starter business].freeze

  has_many :billing_plan_versions, dependent: :restrict_with_exception

  normalizes :code, with: ->(code) { code.to_s.strip.downcase }
  normalizes :display_name, with: ->(name) { name.to_s.strip }

  validates :code, presence: true, inclusion: { in: CODES }, uniqueness: true
  validates :display_name, presence: true
end
