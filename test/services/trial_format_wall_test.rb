require "test_helper"

class TrialFormatWallTest < ActiveSupport::TestCase
  setup do
    @user = create_user_with_workspace
    @workspace = @user.workspaces.first
  end

  test "lists only custom (non-default) formats" do
    create_format("Meeting Notes")
    create_format("Action Items")

    wall = TrialFormatWall.new(@workspace)

    assert_equal 2, wall.formats_count
    assert_equal [ "Action Items", "Meeting Notes" ], wall.formats.map(&:name)
  end

  test "excludes the default format from the proof list" do
    default_profile = @workspace.transformer_profiles.find_by!(default: true)
    create_format("Custom")

    wall = TrialFormatWall.new(@workspace)

    assert_not_includes wall.formats.map(&:name), default_profile.name
  end

  test "returns zero when no custom formats exist" do
    wall = TrialFormatWall.new(@workspace)

    assert_equal 0, wall.formats_count
    assert_empty wall.formats
  end

  private

  def create_format(name)
    @workspace.transformer_profiles.create!(
      name: name,
      handle: name.parameterize,
      instructions: TransformerProfile::DEFAULT_INSTRUCTIONS,
      active: true,
      default: false
    )
  end
end
