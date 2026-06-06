require "application_system_test_case"

class MarketingPagesTest < ApplicationSystemTestCase
  test "about page is reachable from footer on public pages" do
    visit root_path
    within("footer") { click_link "About" }
    assert_current_path about_path, ignore_query: true
    assert_text "About Nodl"

    visit login_path
    within("footer") { click_link "About" }
    assert_current_path about_path, ignore_query: true

    visit register_path
    within("footer") { click_link "About" }
    assert_current_path about_path, ignore_query: true
  end

  test "footer links work on authenticated pages" do
    email = unique_email("footer")
    create_user_with_workspace(email: email, password: "Valid123")

    login_via_ui(email: email, password: "Valid123")
    assert_current_path dashboard_path, ignore_query: true

    within("footer") { click_link "Pricing" }
    assert_current_path payments_path, ignore_query: true

    within("footer") { click_link "Demo" }
    assert_current_path try_now_path, ignore_query: true
  end
end
