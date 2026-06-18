class Workspace < ApplicationRecord
  self.ignored_columns += %w[
    subscription_status
    subscription_plan
    subscription_billing_cycle
    usage_limits
    usage_consumption
  ]

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :recording_sessions, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :transformer_profiles, dependent: :destroy
  has_many :usage_events, dependent: :destroy
  has_one :current_entitlement, class_name: "WorkspaceEntitlement", dependent: :destroy

  # Encrypt the workspace display name at rest (Active Record Encryption).
  # `slug` stays plaintext: it is the indexed, queried tenant identifier.
  encrypts :name

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :slug, with: ->(slug) { slug.to_s.parameterize }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :ensure_slug
  after_create :ensure_trial_entitlement
  after_create :ensure_default_transformer_profile

  def on_trial?
    current_entitlement&.plan_code == "trial"
  end

  def recording_limit_reached?
    EntitlementPolicy.new(self).allowed?(:recordings).denied?
  end

  def format_limit_reached?
    EntitlementPolicy.new(self).allowed?(:custom_formats).denied?
  end

  def entitlement_for(capability, quantity: 1, unit: "count", subject: nil)
    EntitlementPolicy.new(self).allowed?(capability, quantity:, unit:, subject:)
  end

  private

  def ensure_slug
    return if slug.present?

    base = name.presence || "workspace"
    self.slug = "#{base.parameterize}-#{SecureRandom.alphanumeric(6).downcase}"
  end

  def ensure_default_transformer_profile
    TransformerProfile.ensure_default_for!(self)
  end

  def ensure_trial_entitlement
    return if current_entitlement.present?

    WorkspaceEntitlementGrant.grant!(
      workspace: self,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Default entitlement for new workspace"
    )
    association(:current_entitlement).reset
  end
end
