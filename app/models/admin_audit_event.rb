class AdminAuditEvent < ApplicationRecord
  belongs_to :user
  belongs_to :acting_admin, class_name: "User", inverse_of: :acting_admin_audit_events

  validates :action, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
