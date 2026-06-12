# frozen_string_literal: true

# Dynamically loads private initializers, locales, and code from the git-ignored
# `private/` directory, if it exists. Private views are prepended per request in
# ApplicationController so tests can isolate OSS and private modes.
#
# This allows the host/operator of this specific instance to hook into
# ActiveSupport::Notifications or extend the app privately without modifying
# the public open-source repository.
require Rails.root.join("lib/private_content")

if Dir.exist?(PrivateContent.root)
  Rails.application.config.i18n.load_path += PrivateContent.locale_paths

  # Load initializers
  Dir[PrivateContent.root.join("initializers/**/*.rb")].each do |file|
    require file
  end
end
