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

  # The recorder UI subscribes to LiveTranscriptionChannel, whose default
  # factory opens real websockets to api.mistral.ai (network in tests, API
  # quota, audio leaving the machine). Capybara's Puma runs in-process, so
  # swapping the factory here takes effect in the app under test.
  class FakeRealtimeClient
    def start(&_handler); end

    def send_audio(_audio); end

    def close; end
  end

  setup do
    skip "Set JS_SYSTEM_TESTS=1 to run browser JS system tests" unless ENV["JS_SYSTEM_TESTS"] == "1"
    @original_realtime_client_factory = LiveTranscriptionChannel.realtime_client_factory
    LiveTranscriptionChannel.realtime_client_factory = ->(**) { FakeRealtimeClient.new }
  end

  teardown do
    if defined?(@original_realtime_client_factory) && @original_realtime_client_factory
      LiveTranscriptionChannel.realtime_client_factory = @original_realtime_client_factory
    end
  end
end
