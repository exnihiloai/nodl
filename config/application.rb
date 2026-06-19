require_relative "boot"

require "rails/all"

require_relative "../lib/app_version"
require_relative "../lib/markdown_for_agents"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Nodl
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # nodl and observability are self-contained libraries wired with manual
    # require/require_relative (and define multiple constants per file), so they
    # must stay out of Zeitwerk to avoid double-loading/superclass-mismatch.
    config.autoload_lib(ignore: %w[assets tasks nodl observability])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.x.app_version = AppVersion.current
    config.middleware.use MarkdownForAgents

    # Internationalization: English is the source language, German is the first
    # added translation. Locale files may be nested in subdirectories.
    config.i18n.available_locales = %i[en de]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [ :en ]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]

    # Active Record Encryption keys come from the environment, never from the
    # repo: nodl is public, so even the encrypted credentials file must not
    # carry them. Production requires all three vars (set in Dokploy; canonical
    # copy lives in private/secrets/production-encryption.env) and fails the
    # boot fast when they are missing — except during the image build's asset
    # precompile, which runs without secrets (SECRET_KEY_BASE_DUMMY).
    # Development falls back to fixed throwaway keys so OSS clones run out of
    # the box (same philosophy as the dev database password in compose); test
    # keys are pinned in config/environments/test.rb.
    if ENV["SECRET_KEY_BASE_DUMMY"].blank? && Rails.env.production?
      config.active_record.encryption.primary_key = ENV.fetch("NODL_AR_ENCRYPTION_PRIMARY_KEY")
      config.active_record.encryption.deterministic_key = ENV.fetch("NODL_AR_ENCRYPTION_DETERMINISTIC_KEY")
      config.active_record.encryption.key_derivation_salt = ENV.fetch("NODL_AR_ENCRYPTION_KEY_DERIVATION_SALT")
    else
      config.active_record.encryption.primary_key =
        ENV.fetch("NODL_AR_ENCRYPTION_PRIMARY_KEY", "nodl-dev-only-insecure-primary-key")
      config.active_record.encryption.deterministic_key =
        ENV.fetch("NODL_AR_ENCRYPTION_DETERMINISTIC_KEY", "nodl-dev-only-insecure-deterministic-key")
      config.active_record.encryption.key_derivation_salt =
        ENV.fetch("NODL_AR_ENCRYPTION_KEY_DERIVATION_SALT", "nodl-dev-only-insecure-key-derivation-salt")
    end

    # Encrypted columns must hold ciphertext: reading a plaintext value raises
    # instead of being silently tolerated, so a future bug that writes plaintext
    # fails loudly. Operators upgrading an instance with pre-encryption data:
    # set this to true, run `rails encryption:backfill` and
    # `rails encryption:reencrypt_blobs`, then flip it back. See
    # doc/design-output/security/data-encryption.md.
    config.active_record.encryption.support_unencrypted_data = false

    # Name of the (encrypted) Active Storage service that attachments are pinned
    # to. active_storage_encryption only generates a per-blob key when the blob
    # carries an explicit service_name, so each has_*_attached passes this. Test
    # overrides it to :test for storage isolation (see config/environments/test.rb).
    config.x.attachment_service = :local
  end
end
