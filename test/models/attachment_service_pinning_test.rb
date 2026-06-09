require "test_helper"

# Guards the blob-encryption guarantee mechanically: active_storage_encryption
# only generates a per-blob key when the blob carries an explicit service_name,
# so every attachment must be pinned via `service:` (see
# config.x.attachment_service in config/application.rb). A declaration without
# it fails at runtime on the first upload — this test moves that failure to CI
# and names the fix.
class AttachmentServicePinningTest < ActiveSupport::TestCase
  test "every Active Storage attachment is pinned to the encrypted service" do
    Rails.application.eager_load!

    offenders = ApplicationRecord.descendants.reject(&:abstract_class?).flat_map do |model|
      model.reflect_on_all_attachments
        .reject { |reflection| reflection.options[:service_name].present? }
        .map { |reflection| "#{model.name}##{reflection.name}" }
    end

    assert_empty offenders,
      "These attachments are missing `service: Rails.application.config.x.attachment_service`, " \
      "so no per-blob encryption key is generated and the first upload raises at runtime: " \
      "#{offenders.join(', ')}"
  end
end
