require "test_helper"

class AppVersionTest < ActiveSupport::TestCase
  test "reads the latest semver from CHANGELOG.md" do
    assert_equal "0.9.3", AppVersion.from_changelog
  end

  test "prefers APP_VERSION when set" do
    with_env("APP_VERSION" => "1.2.3") do
      assert_equal "1.2.3", AppVersion.current
    end
  end

  test "falls back to changelog when APP_VERSION is blank" do
    with_env("APP_VERSION" => nil) do
      assert_equal AppVersion.from_changelog, AppVersion.current
    end
  end

  private

  def with_env(overrides)
    previous = overrides.keys.index_with { |key| ENV.key?(key) ? ENV[key] : :missing }

    overrides.each { |key, value| ENV[key] = value }

    yield
  ensure
    previous.each do |key, value|
      if value == :missing
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
