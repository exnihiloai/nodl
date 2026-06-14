require "test_helper"

# Covers the private marketing mount contract. OSS-only deployments should not
# expose private marketing pages, while deployments with private views mounted
# should route and render them.
class VerticalPagesTest < ActionDispatch::IntegrationTest
  VERTICALS = {
    "/fuer/aerzte" => :for_doctors,
    "/fuer/zahnaerzte" => :for_dentists,
    "/fuer/gedankenkarussell" => :for_overthinkers,
    "/fuer/tagebuch" => :for_journaling,
    "/fuer/interviews" => :for_interviews,
    "/fuer/coaches" => :for_coaches
  }.freeze

  setup do
    @private_views = Rails.root.join("tmp/vertical_pages_test/#{SecureRandom.hex(8)}/views")
    @private_views.join("pages").mkpath
    @private_views.join("pages/home.html.erb").write(<<~ERB)
      <h1>Private landing fixture</h1>
      #{VERTICALS.keys.map { |path| %(<a href="#{path}">#{path}</a>) }.join}
    ERB

    VERTICALS.each_value do |action|
      @private_views.join("pages/#{action}.html.erb").write(<<~ERB)
        <h1>Private #{action} fixture</h1>
        <a href="#{Rails.application.routes.url_helpers.register_path}">Register</a>
      ERB
    end
  end

  teardown do
    FileUtils.rm_rf(@private_views.dirname)
  end

  test "footer vertical links remain visible for signed-out users when marketing is mounted" do
    with_private_view_root(@private_views) do
      get root_path

      assert_response :success
      assert_select "[data-testid='footer-verticals'] a[href=?]", for_doctors_path
    end
  end

  test "footer vertical links are hidden for signed-in users when marketing is mounted" do
    user = create_user_with_workspace(email: "footer-verticals@example.test")

    with_private_view_root(@private_views) do
      post login_path, params: { email: user.email, password: "Valid123" }
      get dashboard_path

      assert_response :success
      assert_select "[data-testid='footer-verticals']", count: 0
      assert_select "footer a[href=?]", for_doctors_path, count: 0
    end
  end

  test "oss-only landing page omits private vertical links" do
    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        get root_path

        assert_response :success
        assert_includes response.body, I18n.t("pages.public_home.heading")
        VERTICALS.each_key do |path|
          assert_select "a[href=?]", path, count: 0
        end
      end
    end
  end

  test "private landing page links to all vertical pages when mounted" do
    with_private_view_root(@private_views) do
      get root_path

      assert_response :success
      assert_includes response.body, "Private landing fixture"
      VERTICALS.each_key do |path|
        assert_select "a[href=?]", path
      end
    end
  end

  test "each private vertical page renders when mounted" do
    with_private_view_root(@private_views) do
      VERTICALS.each do |path, action|
        get path

        assert_response :success
        assert_includes response.body, "Private #{action} fixture"
        assert_select "a[href=?]", register_path
      end
    end
  end

  test "private-only vertical page returns not found when private view is absent" do
    Dir.mktmpdir do |empty_root|
      with_private_view_root(empty_root) do
        get "/fuer/aerzte"

        assert_response :not_found
      end
    end
  end
end
