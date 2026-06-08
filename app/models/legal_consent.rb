# Records a single consent event: which user agreed to which legal document at
# which version (the document's "Stand" date) and when. A new document version
# produces a new row rather than overwriting the prior consent, preserving an
# auditable history of every agreement a user has given.
class LegalConsent < ApplicationRecord
  belongs_to :user

  # Documents that require explicit consent at registration.
  CONSENTABLE_DOCUMENTS = %w[terms privacy].freeze

  validates :document, presence: true, inclusion: { in: CONSENTABLE_DOCUMENTS }
  validates :version, presence: true
  validates :accepted_at, presence: true

  # Records the user's current consent to each consentable document, capturing
  # the live document version plus request metadata for auditability. No-ops for
  # documents that aren't published (OSS deploy without private/legal/).
  def self.record_for(user, request: nil)
    CONSENTABLE_DOCUMENTS.each do |document|
      next unless LegalPage.exists?(document)

      create!(
        user: user,
        document: document,
        version: LegalPage.version(document) || "unversioned",
        accepted_at: Time.current,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent
      )
    end
  end
end
