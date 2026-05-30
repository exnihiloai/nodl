require "application_system_test_case"

class ApplicationJsSystemTestCase < ApplicationSystemTestCase
  if ENV["JS_SYSTEM_TESTS"] == "1"
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]
  end

  setup do
    skip "Set JS_SYSTEM_TESTS=1 to run browser JS system tests" unless ENV["JS_SYSTEM_TESTS"] == "1"
  end
end
