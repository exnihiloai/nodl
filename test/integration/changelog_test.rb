require "test_helper"

class ChangelogTest < ActionDispatch::IntegrationTest
  test "changelog page shows grouped entries" do
    get changelog_path

    assert_response :success
    assert_includes response.body, 'data-testid="changelog-list"'
    assert_includes response.body, 'data-testid="changelog-entry"'
    assert_match(/v0\.9\.3/, response.body)
  end

  test "about page links to changelog" do
    get about_path

    assert_response :success
    assert_includes response.body, 'data-testid="about-changelog-link"'
    assert_includes response.body, changelog_path
  end

  test "version slug route renders changelog board" do
    get changelog_entry_path(version_slug: "v0.9.3")

    assert_response :success
    assert_includes response.body, 'id="cl-v0.9.3"'
    assert_includes response.body, 'data-changelog-board-open-slug-value="v0.9.3"'
  end
end
