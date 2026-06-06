require_relative "boot"

require "rails/all"

require_relative "../lib/app_version"

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

    # Internationalization: English is the source language, German is the first
    # added translation. Locale files may be nested in subdirectories.
    config.i18n.available_locales = %i[en de]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [ :en ]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
  end
end
