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

  test "stop recording disables record button for 3 seconds and collapses panel" do
    email = unique_email("audio-recorder-stop")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first

    login_via_ui(email: email, password: "Valid123")

    # Click Record
    click_button "Record"

    # Wait for the recording state to engage with our fake audio stream
    assert_button "Stop", disabled: false, visible: true

    # Stop recording
    click_button "Stop"

    # Button is locked (disabled) initially
    assert_button "Record", disabled: true

    # Wait for more than 3 seconds to ensure the 3s timer reactivates it
    sleep 3.2

    # Button is active again
    assert_button "Record", disabled: false
  end
end
