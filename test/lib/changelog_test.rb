require "test_helper"

class ChangelogParserTest < ActiveSupport::TestCase
  setup do
    Changelog.reset_cache!
  end

  test "parses versioned entries with sections and item titles" do
    entries = Changelog.changelog_entries
    latest = entries.first

    assert entries.any?
    assert_valid_semver(latest.version)
    assert_match(/\A\d{4}-\d{2}-\d{2}\z/, latest.date)

    # Pin the section/item assertions to a known entry rather than "latest", so
    # adding a newer release (which may have no Added section) does not break the
    # parser test.
    entry = entries.find { |candidate| candidate.version == "0.10.0" }
    assert_includes entry.sections.map(&:key), :added

    added = entry.sections.find { |section| section.key == :added }
    first_item = added.items.first

    assert_equal "Show Password While You Type", first_item.title
    assert_includes first_item.html, "eye button"
  end

  test "groups entries into week columns" do
    columns = Changelog.week_columns

    assert columns.any?
    assert columns.first.entries.any?
    assert_match(/Week|Woche/, columns.first.label)
  end

  test "entry slug matches deep-link format" do
    entry = Changelog.changelog_entries.first

    assert_valid_semver(entry.version)
    assert_equal "v#{entry.version}", entry.slug
    assert_equal "cl-v#{entry.version}", entry.modal_id
  end
end
