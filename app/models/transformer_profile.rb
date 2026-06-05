class TransformerProfile < ApplicationRecord
  DEFAULT_HANDLE = "default"
  DEFAULT_NAME = "Basic Summary"
  DEFAULT_SOURCE_PATH = "transformers/default"

  belongs_to :workspace

  normalizes :handle, with: ->(handle) { handle.to_s.strip }
  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :source_path, with: ->(source_path) { source_path.to_s.strip }

  validates :handle, presence: true, format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ }
  validates :handle, uniqueness: { scope: :workspace_id }
  validates :name, presence: true
  validates :source_path, presence: true
  validate :single_default_per_workspace

  scope :active, -> { where(active: true) }
  scope :default_first, -> { order(default: :desc, name: :asc, handle: :asc) }

  def self.ensure_default_for!(workspace)
    find_or_create_by!(workspace: workspace, handle: DEFAULT_HANDLE) do |profile|
      profile.name = DEFAULT_NAME
      profile.source_path = DEFAULT_SOURCE_PATH
      profile.default = true
      profile.active = true
    end
  end

  private

  def single_default_per_workspace
    return unless default?
    return if workspace_id.blank?

    duplicate = self.class.where(workspace_id: workspace_id, default: true)
    duplicate = duplicate.where.not(id: id) if persisted?
    errors.add(:default, "transformer already exists for this workspace") if duplicate.exists?
  end
end
