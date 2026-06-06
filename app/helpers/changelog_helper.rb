# frozen_string_literal: true

module ChangelogHelper
  SECTION_BADGES = {
    added: { badge: "badge-success", label_key: "changelog.badges.feature" },
    fixed: { badge: "badge-warning", label_key: "changelog.badges.fix" },
    changed: { badge: "badge-info", label_key: "changelog.badges.update" },
    removed: { badge: "badge-ghost", label_key: "changelog.sections.removed" },
    security: { badge: "badge-error", label_key: "changelog.badges.security" },
    technical: { badge: "badge-neutral", label_key: "changelog.badges.technical" },
    other: { badge: "badge-ghost", label_key: nil }
  }.freeze

  def changelog_section_badge(section)
    config = SECTION_BADGES.fetch(section.key, SECTION_BADGES[:other])
    label = config[:label_key] ? t(config[:label_key]) : t("changelog.sections.#{section.key}", default: section.key.to_s.humanize)
    { class_name: config[:badge], label: label }
  end

  def changelog_formatted_date(date)
    parts = date.to_s.split("-")
    return date unless parts.length == 3

    if I18n.locale == :de
      "#{parts[2]}.#{parts[1]}.#{parts[0]}"
    else
      Date.new(parts[0].to_i, parts[1].to_i, parts[2].to_i).strftime("%B %-d, %Y")
    end
  rescue ArgumentError
    date
  end
end
