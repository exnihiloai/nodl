source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Transitive via mail; pin for CVE-2026-47240/47241/47242 (bundler-audit).
gem "net-imap", ">= 0.6.4.1"
# Catch unsafe migrations (locking/blocking operations) at db:migrate time.
gem "strong_migrations", "~> 2.8"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-rails_csrf_protection", "~> 1.0"
# Edge rate limiting + malicious-probe blocking (counters live in Rails.cache).
gem "rack-attack", "~> 6.7"
gem "stripe", "~> 13.0"
gem "kramdown", "~> 2.4.0"
# Pure-Ruby document export for downloads: PDF (prawn/prawn-html) and Word (htmltoword). No native binaries.
gem "prawn", "~> 2.5"
gem "prawn-html", "~> 0.6"
gem "htmltoword", "~> 1.0"
# Pure-Ruby text extraction for custom format example files (no native binaries)
gem "pdf-reader", "~> 2.12"
gem "docx", "~> 0.8"
gem "async-websocket", "~> 0.30"
gem "web-push", "~> 3.0"
gem "tailwindcss-rails"
gem "opentelemetry-sdk", "~> 1.10"
gem "opentelemetry-exporter-otlp", "~> 0.34.0"
gem "opentelemetry-logs-sdk", "~> 0.6.0"
gem "opentelemetry-exporter-otlp-logs", "~> 0.5.1"
gem "opentelemetry-metrics-sdk", "~> 0.14.0"
gem "opentelemetry-exporter-otlp-metrics", "~> 0.9.1"
gem "opentelemetry-instrumentation-rails", "~> 0.42.0"
gem "opentelemetry-instrumentation-logger", "~> 0.4.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"
# Encrypt Active Storage blobs at rest with per-blob keys (EncryptedDisk service).
# Supports HTTP Range streaming so audio playback/seek keeps working.
gem "active_storage_encryption", "~> 0.3"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Audits that model validations/associations are backed by DB constraints.
  gem "database_consistency", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Code coverage map (opt-in via COVERAGE=1). A guide to untested paths, not a grade.
  gem "simplecov", require: false
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  # Lightweight mocking/stubbing for Minitest (Rails doesn't ship stubs in Minitest 6+).
  gem "mocha", require: false
  gem "selenium-webdriver"
end
