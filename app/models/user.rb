class User < ApplicationRecord
  has_secure_password

  enum :role, { user: 0, admin: 1 }, default: :user

  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :created_recording_sessions, class_name: "RecordingSession", foreign_key: :creator_id, inverse_of: :creator, dependent: :restrict_with_exception
  has_many :admin_audit_events, dependent: :destroy
  has_many :acting_admin_audit_events, class_name: "AdminAuditEvent", foreign_key: :acting_admin_id, inverse_of: :acting_admin, dependent: :destroy

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :preferred_language, inclusion: { in: %w[en de] }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :password_complexity

  scope :active_only, -> { where(active: true) }

  def display_role
    role.to_s.capitalize
  end

  private

  def password_complexity
    return if password.blank?

    unless password.match?(/[A-Z]/) && password.match?(/[a-z]/) && password.match?(/\d/)
      errors.add(:password, "must include uppercase, lowercase, and a number")
    end
  end
end
