require "application_js_system_test_case"

class ThemeSwitcherJsTest < ApplicationJsSystemTestCase
  test "theme toggle updates and persists across navigation" do
    visit root_path

    toggle = find("input[data-theme-target='toggle']", visible: :all)
    initial_theme = page.evaluate_script("document.documentElement.getAttribute('data-theme')")

    toggle.click

    changed_theme = page.evaluate_script("document.documentElement.getAttribute('data-theme')")
    assert_not_equal initial_theme, changed_theme

    stored_theme = page.evaluate_script("window.localStorage.getItem('theme_preference')")
    assert_equal changed_theme, stored_theme

    visit licenses_path
    assert_equal changed_theme, page.evaluate_script("document.documentElement.getAttribute('data-theme')")
  end
end
