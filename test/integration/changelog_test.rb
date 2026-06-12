require "test_helper"

class ChangelogTest < ActionDispatch::IntegrationTest
  setup do
    Changelog.reset_cache!
    @latest_entry = Changelog.changelog_entries.first
  end

  test "changelog page shows grouped entries" do
    get changelog_path

    assert_response :success
    assert_includes response.body, 'data-testid="changelog-list"'
    assert_includes response.body, 'data-testid="changelog-entry"'
    assert_includes response.body, @latest_entry.slug
  end

  test "about page links to changelog when private marketing is mounted" do
    with_private_about_page do
      get about_path

      assert_response :success
      assert_includes response.body, 'data-testid="about-changelog-link"'
      assert_includes response.body, changelog_path
    end
  end

  test "version slug route renders changelog board" do
    get changelog_entry_path(version_slug: @latest_entry.slug)

    assert_response :success
    assert_includes response.body, %(id="#{@latest_entry.modal_id}")
    assert_includes response.body, %(data-changelog-board-open-slug-value="#{@latest_entry.slug}")
  end
end
