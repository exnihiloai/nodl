require "test_helper"

class TransformerProfileTest < ActiveSupport::TestCase
  test "workspace creates a default transformer profile stored in the database" do
    user = create_user_with_workspace
    workspace = user.workspaces.first

    default = workspace.transformer_profiles.find_by(default: true)

    assert_equal "default", default.handle
    assert_equal "Basic Summary", default.name
    assert_includes default.instructions, "well-structured Markdown"
    assert_equal [ "example.md" ], default.example_files.map { |file| file.filename.to_s }
  end

  test "only one default transformer is valid per workspace" do
    workspace = create_user_with_workspace.workspaces.first
    duplicate = workspace.transformer_profiles.build(
      handle: "meeting-notes",
      name: "Meeting Notes",
      instructions: "Make meeting notes.",
      default: true
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:default], "transformer already exists for this workspace"
  end

  test "requires instructions" do
    profile = build_profile(instructions: "")

    assert_not profile.valid?
    assert_includes profile.errors[:instructions], "can't be blank"
  end

  test "rejects more than three example files" do
    profile = build_profile
    4.times { |i| attach_example(profile, "ex#{i}.txt") }

    assert_not profile.valid?
    assert_includes profile.errors[:example_files], "You can add up to 3 example documents."
  end

  test "rejects unsupported example file formats" do
    profile = build_profile
    attach_example(profile, "logo.png", content_type: "image/png")

    assert_not profile.valid?
    assert profile.errors[:example_files].any? { |m| m.include?("unsupported format") }
  end

  test "accepts up to three supported example files" do
    profile = build_profile
    3.times { |i| attach_example(profile, "ex#{i}.txt") }

    assert profile.valid?, profile.errors.full_messages.to_sentence
  end

  test "rejects new format when workspace reached format limit" do
    workspace = create_user_with_workspace.workspaces.first
    WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Exercise trial format limit"
    )

    2.times do |index|
      workspace.transformer_profiles.create!(
        name: "Format #{index}",
        handle: "format-#{index}",
        instructions: "Guidelines #{index}."
      )
    end

    profile = workspace.transformer_profiles.build(
      name: "One too many",
      handle: "one-too-many",
      instructions: "Too many formats."
    )

    assert_not profile.valid?
    assert_includes profile.errors[:base], "You've reached the maximum of 2 formats."
  end

  private

  def build_profile(instructions: "Write a friendly summary.")
    workspace = create_user_with_workspace.workspaces.first
    workspace.transformer_profiles.build(
      handle: "journal-#{SecureRandom.hex(3)}",
      name: "Journal",
      instructions: instructions
    )
  end

  def attach_example(profile, filename, content_type: "text/plain")
    profile.example_files.attach(
      io: StringIO.new("Example content"),
      filename: filename,
      content_type: content_type
    )
  end
end
