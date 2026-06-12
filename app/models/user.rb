class User < ApplicationRecord
  has_secure_password

  attr_accessor :oauth_new_user

  enum :role, { user: 0, admin: 1 }, default: :user

  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :created_recording_sessions, class_name: "RecordingSession", foreign_key: :creator_id, inverse_of: :creator, dependent: :restrict_with_exception
  has_many :admin_audit_events, dependent: :destroy
  has_many :legal_consents, dependent: :destroy
  has_many :acting_admin_audit_events, class_name: "AdminAuditEvent", foreign_key: :acting_admin_id, inverse_of: :acting_admin, dependent: :destroy

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :preferred_language, inclusion: { in: %w[en de] }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :uid, uniqueness: { scope: :provider }, allow_nil: true
  validate :password_complexity

  scope :active_only, -> { where(active: true) }

  def display_role
    role.to_s.capitalize
  end

  def self.from_google_oauth!(auth)
    provider = auth.fetch("provider")
    uid = auth.fetch("uid")
    info = auth.fetch("info")
    email = info.fetch("email").to_s.strip.downcase
    name = info["name"].presence
    avatar_url = info["image"].presence

    user = find_by(provider:, uid:) || find_by(email:)
    created_user = false

    if user && !user.active?
      user.oauth_new_user = false
      return user
    end

    ActiveRecord::Base.transaction do
      if user&.provider.present? && (user.provider != provider || user.uid != uid)
        user.errors.add(:base, "is already linked to another identity")
        raise ActiveRecord::RecordInvalid, user
      end

      generated_password = SecureRandom.base58(32)
      user ||= create!(
        email:,
        password: generated_password,
        password_confirmation: generated_password,
        preferred_language: "en"
      ).tap { created_user = true }

      user.update!(
        provider: provider,
        uid: uid,
        name: name || user.name,
        avatar_url: avatar_url || user.avatar_url
      )

      ensure_default_workspace_for!(user)
      user.oauth_new_user = created_user
      user
    end
  end

  def self.ensure_default_workspace_for!(user)
    return if user.workspaces.exists?

    workspace = Workspace.create!(
      name: "#{user.email.split("@").first.titleize} Workspace",
      usage_limits: { scans: 1000, storage_mb: 1024 },
      usage_consumption: { scans: 0, storage_mb: 0 }
    )

    Membership.create!(user:, workspace:, role: :owner)
  end
  private_class_method :ensure_default_workspace_for!

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/[A-Z]/) && password.match?(/[a-z]/) && password.match?(/\d/)
      errors.add(:password, :password_complexity)
    end
  end
end
