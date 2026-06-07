require "test_helper"

class ChangelogParserTest < ActiveSupport::TestCase
  setup do
    Changelog.reset_cache!
  end

  test "parses versioned entries with sections and item titles" do
    entries = Changelog.changelog_entries
    latest = entries.first

    assert_equal "0.9.5", latest.version
    assert_equal "2026-06-07", latest.date
    assert_includes latest.sections.map(&:key), :fixed

    fixed = latest.sections.find { |section| section.key == :fixed }
    first_item = fixed.items.first

    assert_equal "Signed-in Visits Go Straight to the Dashboard", first_item.title
    assert_includes first_item.html, "directly to your dashboard"
  end

  test "groups entries into week columns" do
    columns = Changelog.week_columns

    assert columns.any?
    assert columns.first.entries.any?
    assert_match(/Week|Woche/, columns.first.label)
  end

  test "entry slug matches deep-link format" do
    entry = Changelog.changelog_entries.first

    assert_equal "v0.9.5", entry.slug
    assert_equal "cl-v0.9.5", entry.modal_id
  end
end
