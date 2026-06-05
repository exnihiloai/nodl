require "application_js_system_test_case"

class DeleteFormatModalTest < ApplicationJsSystemTestCase
  test "deleting a format uses a styled modal instead of the native confirm" do
    profile = create_deletable_profile

    visit transformer_profile_path(profile)

    # Cancelling keeps the format.
    find("[data-testid='delete-format-button']").click
    assert_selector "dialog.modal[open]"
    assert_text "Delete this format? This cannot be undone."
    within("dialog.modal") { click_button "Cancel" }
    assert_no_selector "dialog.modal[open]"
    assert_current_path transformer_profile_path(profile)
    assert TransformerProfile.exists?(profile.id)

    # Confirming deletes it.
    find("[data-testid='delete-format-button']").click
    assert_selector "dialog.modal[open]"
    within("dialog.modal") { click_button "Delete" }

    assert_current_path dashboard_path
    assert_not TransformerProfile.exists?(profile.id)
  end

  private

  def create_deletable_profile
    email = unique_email
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    profile = workspace.transformer_profiles.create!(
      name: "Journal",
      handle: "journal",
      instructions: "Reflective entries."
    )

    login_via_ui(email: email, password: "Valid123")
    assert_selector "[data-testid='account-menu']"
    profile
  end
end
