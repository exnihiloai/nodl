require "application_js_system_test_case"

class FlashAutoDismissTest < ApplicationJsSystemTestCase
  test "success flash appears then disappears on its own" do
    visit root_path
    execute_script <<~JS
      const flash = document.createElement("div")
      flash.setAttribute("role", "alert")
      flash.setAttribute("data-controller", "flash")
      flash.textContent = "Account created successfully."
      document.body.appendChild(flash)
    JS

    # The success notice is rendered, then auto-dismisses without any user action.
    assert_selector "[role='alert']", text: "Account created successfully.", visible: :all
    assert_no_selector "[role='alert']", text: "Account created successfully.", visible: :all, wait: 7
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
