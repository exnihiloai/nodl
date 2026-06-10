require "test_helper"
require "fugit"

# Guards config/recurring.yml mechanically: Solid Queue only resolves a
# recurring entry's class/command when the schedule fires, so a typo there
# fails silently at runtime in production. This test moves that failure to
# `make check` and names the bad entry.
class RecurringJobsConfigTest < ActiveSupport::TestCase
  CONFIG_PATH = Rails.root.join("config", "recurring.yml")

  test "every recurring.yml entry resolves" do
    ActiveSupport::ConfigurationFile.parse(CONFIG_PATH).each do |environment, entries|
      (entries || {}).each do |name, entry|
        label = "#{environment}.#{name}"
        klass, command, schedule = entry.values_at("class", "command", "schedule")

        assert klass.present? ^ command.present?,
          "recurring.yml entry #{label} must define exactly one of `class:` or `command:`"
        assert_resolvable_class(label, klass) if klass.present?
        assert_parseable_command(label, command) if command.present?

        assert schedule.present?,
          "recurring.yml entry #{label} is missing `schedule:`"
        assert_not_nil Fugit.parse(schedule),
          "recurring.yml entry #{label} has a schedule Fugit cannot parse: #{schedule.inspect} — " \
          "use a cron line or a supported natural phrase (e.g. \"every day at 3am\")"
      end
    end
  end

  private

  def assert_resolvable_class(label, klass)
    resolved = begin
      klass.constantize
    rescue NameError
      flunk "recurring.yml entry #{label} names `class: #{klass}` which does not resolve — " \
            "fix the typo or add the job under app/jobs/"
    end
    assert resolved.respond_to?(:perform_later),
      "recurring.yml entry #{label} resolves `class: #{klass}` to a non-job " \
      "(no perform_later) — point it at an ActiveJob subclass"
  end

  def assert_parseable_command(label, command)
    RubyVM::AbstractSyntaxTree.parse(command)
    receiver = command[/\A\s*([A-Z][A-Za-z0-9_:]*)/, 1]
    return if receiver.nil? # not a constant call; syntax already validated above

    receiver.constantize
  rescue SyntaxError => error
    flunk "recurring.yml entry #{label} has a `command:` that is not valid Ruby: #{error.message}"
  rescue NameError
    flunk "recurring.yml entry #{label} has a `command:` whose receiver `#{receiver}` " \
          "does not resolve — fix the constant name"
  end
end
