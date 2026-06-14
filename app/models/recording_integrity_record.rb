class RecordingIntegrityRecord < ApplicationRecord
  HASH_ALGORITHM_SHA256 = "sha256".freeze
  STATUS_SEALED = "sealed".freeze
  STATUS_FAILED = "failed".freeze
  STATUS_PENDING_CONFIG = "pending_config".freeze
  STATUSES = [ STATUS_SEALED, STATUS_FAILED, STATUS_PENDING_CONFIG ].freeze
  PROOF_FORMAT_RFC3161 = "rfc3161-tsr".freeze

  belongs_to :recording_session

  validates :recording_session_id, uniqueness: true
  validates :hash_sha256, presence: true, length: { is: 64 }, format: { with: /\A\h{64}\z/ }
  validates :hash_algorithm, presence: true, inclusion: { in: [ HASH_ALGORITHM_SHA256 ] }, length: { maximum: 20 }
  validates :hashed_at, presence: true
  validates :tsa_status, presence: true, inclusion: { in: STATUSES }, length: { maximum: 30 }
  validates :tsa_provider, presence: true, length: { maximum: 80 }
  validates :tsa_authority, length: { maximum: 255 }, allow_nil: true
  validates :tsa_proof_format, length: { maximum: 50 }, allow_nil: true
  validates :tsa_error, length: { maximum: 500 }, allow_nil: true

  scope :retryable, -> { where(tsa_status: [ STATUS_FAILED, STATUS_PENDING_CONFIG ]) }

  def sealed?
    tsa_status == STATUS_SEALED
  end
end
