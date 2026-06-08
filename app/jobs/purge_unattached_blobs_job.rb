class PurgeUnattachedBlobsJob < ApplicationJob
  queue_as :default

  # Active Storage stores a blob before it is attached to a record (direct/abandoned
  # uploads, failed creates). On the EncryptedDisk service these orphans are already
  # ciphertext, but we still purge them so no durable fragments linger. Scheduled
  # daily via config/recurring.yml. RETENTION keeps a margin so an upload still in
  # flight toward attachment is never purged out from under it.
  RETENTION = 1.day

  def perform(older_than: RETENTION.ago)
    ActiveStorage::Blob.unattached.where(created_at: ..older_than).find_each(&:purge_later)
  end
end
