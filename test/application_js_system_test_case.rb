require "application_system_test_case"
require "selenium/webdriver"

class ApplicationJsSystemTestCase < ApplicationSystemTestCase
  if ENV["JS_SYSTEM_TESTS"] == "1"
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--window-size=1400,1000")
      # Enable fake media devices for microphone testing
      options.add_argument("--use-fake-ui-for-media-stream")
      options.add_argument("--use-fake-device-for-media-stream")
      options.binary = ENV.fetch("CHROME_BIN", "/usr/bin/chromium")
    end
  end

  setup do
    skip "Set JS_SYSTEM_TESTS=1 to run browser JS system tests" unless ENV["JS_SYSTEM_TESTS"] == "1"
  end
end
