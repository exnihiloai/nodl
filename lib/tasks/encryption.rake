namespace :encryption do
  # Models whose sensitive columns are wrapped with Active Record Encryption.
  ENCRYPTED_MODELS = %w[Workspace TransformerProfile RecordingSession Document].freeze

  desc "Encrypt existing rows in place for all models with encrypted columns " \
       "(safe to run repeatedly; requires support_unencrypted_data during rollout)."
  task backfill: :environment do
    ENCRYPTED_MODELS.each do |name|
      model = name.constantize
      count = 0
      model.find_each do |record|
        # #encrypt re-writes the encryptable attributes as ciphertext and saves.
        # It is a no-op for rows that are already encrypted.
        record.encrypt
        count += 1
      end
      puts "encryption:backfill #{name}: processed #{count} record(s)"
    end
  end

  desc "Re-encrypt legacy Active Storage blobs that were stored before the " \
       "EncryptedDisk service was enabled (idempotent; reads the plaintext file, " \
       "rewrites it encrypted, and assigns a per-blob key)."
  task reencrypt_blobs: :environment do
    migrated = 0
    skipped = 0
    failed = 0

    ActiveStorage::Blob.where(encryption_key: nil).find_each do |blob|
      service = blob.service
      unless service.respond_to?(:encrypted?) && service.encrypted?
        skipped += 1
        next
      end

      # Legacy bytes were written by the stock DiskService at the unencrypted path
      # (no ".encrypted-v*" suffix) under the same root.
      plain = ActiveStorage::Service::DiskService.new(root: service.root)
      unless plain.exist?(blob.key)
        warn "encryption:reencrypt_blobs: plaintext file missing for blob #{blob.id} (#{blob.key}); skipping"
        skipped += 1
        next
      end

      begin
        plaintext = plain.download(blob.key)
        blob.encryption_key = ActiveStorage::Blob.send(:generate_random_encryption_key)
        service.upload(blob.key, StringIO.new(plaintext), checksum: blob.checksum, encryption_key: blob.encryption_key)
        blob.save!
        plain.delete(blob.key) # remove the now-redundant plaintext copy
        migrated += 1
      rescue => e
        warn "encryption:reencrypt_blobs: failed for blob #{blob.id} (#{blob.key}): #{e.class}: #{e.message}"
        failed += 1
      end
    end

    puts "encryption:reencrypt_blobs: migrated=#{migrated} skipped=#{skipped} failed=#{failed}"
  end
end
