require "application_js_system_test_case"

class FlashAutoDismissTest < ApplicationJsSystemTestCase
  test "success flash appears then disappears on its own" do
    register_via_ui(email: unique_email, password: "Valid123")

    # The success notice shows after registration...
    assert_text "Account created successfully."
    # ...and then auto-dismisses without any user action.
    assert_no_text "Account created successfully.", wait: 7
  end

  test "error flash stays so it can be read" do
    visit login_path
    fill_in "login_email", with: "nobody@example.test"
    fill_in "login_password", with: "WrongPass1"
    click_button "Sign in"

    assert_text "Invalid credentials."
    # Still present after the success auto-dismiss window would have elapsed.
    sleep 5
    assert_text "Invalid credentials."
  end
end
