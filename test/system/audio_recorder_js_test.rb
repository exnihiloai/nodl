require "application_js_system_test_case"

class AudioRecorderJsTest < ApplicationJsSystemTestCase
  test "dashboard loads microphone recording controls" do
    email = unique_email("audio-recorder")
    create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")

    assert_selector "[data-testid='recording-form'][data-controller~='audio-recorder']"
    assert_selector "[data-testid='record-button']", text: "Record"
    assert_selector "[data-testid='recording-aura']", visible: :hidden
    assert_button "Stop", disabled: true, visible: :hidden
  end
end
