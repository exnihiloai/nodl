require "test_helper"

class TransformerProfileTest < ActiveSupport::TestCase
  test "workspace creates a default transformer profile" do
    user = create_user_with_workspace
    workspace = user.workspaces.first

    default = workspace.transformer_profiles.find_by(default: true)

    assert_equal "default", default.handle
    assert_equal "Basic Summary", default.name
    assert_equal "transformers/default", default.source_path
  end

  test "only one default transformer is valid per workspace" do
    workspace = create_user_with_workspace.workspaces.first
    duplicate = workspace.transformer_profiles.build(
      handle: "meeting-notes",
      name: "Meeting Notes",
      source_path: "transformers/meeting-notes",
      default: true
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:default], "transformer already exists for this workspace"
  end
end
