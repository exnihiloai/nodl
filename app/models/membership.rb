class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  enum :role, { owner: 0, admin: 1, member: 2 }, default: :member

  validates :user_id, uniqueness: { scope: :workspace_id }
end
