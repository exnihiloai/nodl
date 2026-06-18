require "application_js_system_test_case"

class FormatWallJsTest < ApplicationJsSystemTestCase
  test "wall opens on the reach-forward when trial format limit is reached" do
    email = unique_email("fwall")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    create_format(user, workspace, name: "Meeting Notes")
    create_format(user, workspace, name: "Action Items")

    login_via_ui(email: email, password: "Valid123")

    # Limit reached: "+ New format" button is present but modal is closed.
    assert_selector "[data-testid='format-limit-reached']"
    assert_no_selector "[data-testid='format-wall-modal'][open]"

    # The reach-forward opens the wall instead of navigating.
    find("[data-testid='new-format-button']").click

    assert_selector "[data-testid='format-wall-modal'][open]"
    assert_text "Build a format for every kind of document"
    assert_selector "[data-testid='format-wall-upgrade-button']", text: "Upgrade to Starter"
    assert_selector "[data-testid='format-wall-see-plans-button']", text: "See plans"
    assert_selector "[data-testid='format-wall-formats']", text: "Meeting Notes"

    find("[data-testid='format-wall-dismiss']").click
    assert_no_selector "[data-testid='format-wall-modal'][open]"
  end

  test "new format link navigates normally when under the limit" do
    email = unique_email("fwall-under")
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    grant_trial!(workspace)
    create_format(user, workspace, name: "Only Format")

    login_via_ui(email: email, password: "Valid123")

    assert_no_selector "[data-testid='format-limit-reached']"
    assert_selector "[data-testid='new-format-button']"

    find("[data-testid='new-format-button']").click

    assert_current_path new_transformer_profile_path
  end

  private

  def grant_trial!(workspace)
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Format wall system test"
    )
    workspace.association(:current_entitlement).reset
  end

  def create_format(user, workspace, name:)
    workspace.transformer_profiles.create!(
      name: name,
      handle: name.parameterize,
      instructions: TransformerProfile::DEFAULT_INSTRUCTIONS,
      active: true,
      default: false
    )
  end
end
