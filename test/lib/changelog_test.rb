require "test_helper"

class ChangelogParserTest < ActiveSupport::TestCase
  setup do
    Changelog.reset_cache!
  end

  test "parses versioned entries with sections and item titles" do
    entries = Changelog.changelog_entries
    latest = entries.first

    assert_equal "0.9.4", latest.version
    assert_equal "2026-06-06", latest.date
    assert_includes latest.sections.map(&:key), :added
    assert_includes latest.sections.map(&:key), :technical

    added = latest.sections.find { |section| section.key == :added }
    first_item = added.items.first

    assert_equal "Browse What's New in the App", first_item.title
    assert_includes first_item.html, "/changelog"
  end

  test "groups entries into week columns" do
    columns = Changelog.week_columns

    assert columns.any?
    assert columns.first.entries.any?
    assert_match(/Week|Woche/, columns.first.label)
  end

  test "entry slug matches deep-link format" do
    entry = Changelog.changelog_entries.first

    assert_equal "v0.9.4", entry.slug
    assert_equal "cl-v0.9.4", entry.modal_id
  end
end
