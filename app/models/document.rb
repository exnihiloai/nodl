class Document < ApplicationRecord
  belongs_to :workspace
  belongs_to :recording_session

  normalizes :title, with: ->(title) { title.to_s.strip }
  normalizes :transformer_handle, with: ->(handle) { handle.to_s.strip }

  validates :title, :content, :generated_at, :transformer_handle, presence: true
  validates :transformer_handle, format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ }
  # One document per recording session (has_one), backed by a unique index.
  validates :recording_session_id, uniqueness: true

  scope :recent_first, -> { order(generated_at: :desc, created_at: :desc) }
end
