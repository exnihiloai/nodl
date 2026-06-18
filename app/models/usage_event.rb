class UsageEvent < ApplicationRecord
  EVENT_KINDS = %w[
    recording_created
    custom_format_created
    document_exported
    original_audio_downloaded
    integrity_check_attempted
    recorded_audio_seconds
  ].freeze

  belongs_to :workspace
  belongs_to :user, optional: true

  normalizes :event_kind, with: ->(kind) { kind.to_s.strip }
  normalizes :unit, with: ->(unit) { unit.to_s.strip.presence || "count" }

  validates :event_kind, presence: true, inclusion: { in: EVENT_KINDS }
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, presence: true
  validates :occurred_at, presence: true
end
