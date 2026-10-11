require "test_helper"

class FormatPresetsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user_with_workspace(email: "presets@example.test")
    @workspace = @user.workspaces.first
    post login_path, params: { email: @user.email, password: "Valid123" }
  end

  test "a preset pre-fills the new format form" do
    get new_transformer_profile_path(preset: "session_note")

    assert_response :success
    assert_select "[data-testid=format-name-input][value=?]", I18n.t("format_presets.session_note.name")
    assert_select "[data-testid=format-instructions-input]", text: /#{Regexp.escape(I18n.t("format_presets.session_note.instructions").lines.first.strip)}/
  end

  test "an unknown preset falls back to an empty form" do
    get new_transformer_profile_path(preset: "does_not_exist")

    assert_response :success
    assert_select "[data-testid=format-name-input]:not([value])"
  end

  test "every preset has a name and instructions in both languages" do
    FormatPreset.all.each do |preset|
      %i[de en].each do |locale|
        I18n.with_locale(locale) do
          assert preset.name.present?, "#{preset.key} name missing in #{locale}"
          assert preset.instructions.present?, "#{preset.key} instructions missing in #{locale}"
        end
      end
    end
  end

  test "the dashboard offers presets until the first custom format exists" do
    get dashboard_path
    FormatPreset.all.each do |preset|
      assert_select "[data-testid=format-preset-#{preset.key}][href=?]", new_transformer_profile_path(preset: preset.key)
    end

    @workspace.transformer_profiles.create!(name: "Mine", handle: "mine", instructions: "Write it up.")

    get dashboard_path
    assert_select "[data-testid=format-presets]", count: 0
  end
end
