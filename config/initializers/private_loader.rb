# frozen_string_literal: true

# Dynamically loads private initializers and code from the git-ignored and
# docker-ignored `private/` directory, if it exists.
#
# This allows the host/operator of this specific instance to hook into
# ActiveSupport::Notifications or extend the app privately without modifying
# the public open-source repository.
if Dir.exist?(Rails.root.join("private"))
  # Load initializers
  Dir[Rails.root.join("private/initializers/**/*.rb")].each do |file|
    require file
  end
end
