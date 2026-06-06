# frozen_string_literal: true

class AppVersion
  VERSION_HEADING = /\A## \[([^\]]+)\]/

  def self.current
    env_version = ENV["APP_VERSION"].presence
    return env_version if env_version

    from_changelog || "dev"
  end

  def self.from_changelog
    path = changelog_path
    return unless path.file?

    path.each_line do |line|
      match = line.match(VERSION_HEADING)
      return match[1] if match
    end

    nil
  end

  def self.changelog_path
    Rails.root.join("CHANGELOG.md")
  end
end
