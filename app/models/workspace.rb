class Workspace < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :slug, with: ->(slug) { slug.to_s.parameterize }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :ensure_slug

  def usage_limit_for(key, default_value)
    usage_limits.fetch(key.to_s, default_value).to_i
  end

  def usage_consumed_for(key)
    usage_consumption.fetch(key.to_s, 0).to_i
  end

  private

  def ensure_slug
    return if slug.present?

    base = name.presence || "workspace"
    self.slug = "#{base.parameterize}-#{SecureRandom.alphanumeric(6).downcase}"
  end
end
