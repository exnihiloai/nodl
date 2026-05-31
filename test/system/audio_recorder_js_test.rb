require "application_js_system_test_case"

class AudioRecorderJsTest < ApplicationJsSystemTestCase
  test "dashboard loads microphone recording controls" do
    email = unique_email("audio-recorder")
    create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")

    assert_selector "[data-controller~='audio-recorder']"
    assert_button "Start recording"
    assert_button "Stop", disabled: true
  end
end
