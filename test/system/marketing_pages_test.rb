require "application_system_test_case"

class MarketingPagesTest < ApplicationSystemTestCase
  test "oss-only public home renders without private marketing links" do
    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        visit root_path

        assert_text I18n.t("pages.public_home.heading")
        assert_link I18n.t("nav.login")
        assert_link I18n.t("nav.register")
        assert_no_link href: about_path
        assert_no_link href: try_now_path
      end
    end
  end

  test "authenticated pages render with the public footer when private marketing is absent" do
    email = unique_email("footer")
    create_user_with_workspace(email: email, password: "Valid123")

    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        login_via_ui(email: email, password: "Valid123")
        assert_current_path dashboard_path, ignore_query: true
        assert_no_link href: try_now_path
      end
    end
  end
end
