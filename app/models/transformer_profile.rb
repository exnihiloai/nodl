require "nodl/defaults"

class TransformerProfile < ApplicationRecord
  DEFAULT_HANDLE = Nodl::Defaults::TRANSFORMER_HANDLE
  DEFAULT_NAME = "Basic Summary"
  MAX_EXAMPLE_FILES = 3
  ALLOWED_EXAMPLE_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.oasis.opendocument.text
    text/plain
    text/markdown
  ].freeze

  # Canonical guidelines and example for the format every workspace starts with.
  # The CLI keeps its own copy on disk under transformers/default; this is the
  # source of truth for the web app, which is fully database-backed.
  DEFAULT_INSTRUCTIONS = <<~MARKDOWN.freeze
    Create a concise, well-structured Markdown document from the transcript.

    Prefer:

    - A clear title.
    - Short sections with useful headings.
    - Bullet lists for tasks, decisions, or important details.
    - Plain, direct language.

    Do not include commentary about the transformation process.
  MARKDOWN

  DEFAULT_EXAMPLE_FILENAME = "example.md".freeze
  DEFAULT_EXAMPLE_CONTENT = <<~MARKDOWN.freeze
    # Example Document

    ## Summary

    A short overview of the important points.

    ## Details

    - Important point one.
    - Important point two.

    ## Next Steps

    - Follow-up action.
  MARKDOWN

  belongs_to :workspace
  # Pinned to the encrypted service (see config.x.attachment_service).
  has_many_attached :example_files, service: Rails.application.config.x.attachment_service

  # Encrypt the workspace-provided format settings at rest (Active Record
  # Encryption). `handle` stays plaintext: it is the indexed/queried identifier.
  encrypts :instructions
  encrypts :name

  normalizes :handle, with: ->(handle) { handle.to_s.strip }
  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :handle, presence: true, format: { with: /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/ }
  validates :handle, uniqueness: { scope: :workspace_id }
  validates :name, presence: true
  validates :instructions, presence: true
  validate :single_default_per_workspace
  validate :example_files_limit
  validate :example_files_content_types
  validate :workspace_format_limit_not_exceeded, on: :create
  after_create_commit :record_custom_format_usage

  scope :active, -> { where(active: true) }
  # Default profile first, then a stable order by `handle`. We can't ORDER BY
  # `name` in SQL anymore because it is encrypted (ciphertext order is meaningless);
  # `handle` is plaintext and stable.
  scope :default_first, -> { order(default: :desc, handle: :asc) }

  def self.ensure_default_for!(workspace)
    find_or_create_by!(workspace: workspace, handle: DEFAULT_HANDLE) do |profile|
      profile.name = DEFAULT_NAME
      profile.instructions = DEFAULT_INSTRUCTIONS
      profile.default = true
      profile.active = true
      profile.example_files.attach(
        io: StringIO.new(DEFAULT_EXAMPLE_CONTENT),
        filename: DEFAULT_EXAMPLE_FILENAME,
        content_type: "text/markdown"
      )
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

  def example_files_limit
    return unless example_files.attached?
    return if example_files.size <= MAX_EXAMPLE_FILES

    errors.add(:example_files, "You can add up to #{MAX_EXAMPLE_FILES} example documents.")
  end

  def example_files_content_types
    return unless example_files.attached?

    example_files.each do |file|
      next if ALLOWED_EXAMPLE_CONTENT_TYPES.include?(file.content_type)

      errors.add(:example_files, "#{file.filename} has an unsupported format. Supported formats are: .docx, .odt, .pdf, .md, .txt")
    end
  end

  def workspace_format_limit_not_exceeded
    return if default?
    return if workspace.blank?
    result = workspace.entitlement_for(:custom_formats)
    return if result.allowed?

    errors.add(:base, :format_limit_reached, limit: result.limit)
  end

  def record_custom_format_usage
    return if default?

    UsageRecorder.record!(
      workspace:,
      event_kind: "custom_format_created",
      subject: self
    )
  end
end
