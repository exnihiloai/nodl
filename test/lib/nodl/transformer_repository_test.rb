require "test_helper"
require "tmpdir"
require "nodl/transformation/transformer_repository"

class NodlTransformerRepositoryTest < ActiveSupport::TestCase
  test "loads transformer instructions and templates in name order" do
    Dir.mktmpdir do |dir|
      transformer_dir = Pathname.new(dir).join("meeting-notes")
      transformer_dir.join("templates").mkpath
      transformer_dir.join("instructions.md").write("Make meeting notes.")
      transformer_dir.join("templates", "b.md").write("Template B")
      transformer_dir.join("templates", "a.md").write("Template A")
      transformer_dir.join("templates", "ignored.pdf").write("Ignored")

      transformer = Nodl::Transformation::TransformerRepository.new(root_path: dir).fetch("meeting-notes")

      assert_equal "meeting-notes", transformer.handle
      assert_equal "Make meeting notes.", transformer.instructions
      assert_equal %w[a.md b.md], transformer.templates.map(&:name)
      assert_equal [ "Template A", "Template B" ], transformer.templates.map(&:content)
    end
  end

  test "raises a clear error for missing transformer" do
    Dir.mktmpdir do |dir|
      error = assert_raises(Nodl::ValidationError) do
        Nodl::Transformation::TransformerRepository.new(root_path: dir).fetch("missing")
      end

      assert_includes error.message, "Transformer not found: missing"
    end
  end

  test "raises a clear error for missing instructions" do
    Dir.mktmpdir do |dir|
      Pathname.new(dir).join("default").mkpath

      error = assert_raises(Nodl::ValidationError) do
        Nodl::Transformation::TransformerRepository.new(root_path: dir).fetch("default")
      end

      assert_includes error.message, "Transformer instructions missing"
    end
  end

  test "loads a database profile with extracted example templates when a workspace is given" do
    workspace = create_user_with_workspace.workspaces.first
    profile = workspace.transformer_profiles.create!(
      name: "Journal",
      handle: "journal",
      instructions: "Write a reflective journal entry."
    )
    profile.example_files.attach(
      io: StringIO.new("Example journal body."),
      filename: "sample.txt",
      content_type: "text/plain"
    )

    transformer = Nodl::Transformation::TransformerRepository.new.fetch("journal", workspace: workspace)

    assert_equal "journal", transformer.handle
    assert_equal "Write a reflective journal entry.", transformer.instructions
    assert_equal [ "sample.txt" ], transformer.templates.map(&:name)
    assert_equal [ "Example journal body." ], transformer.templates.map(&:content)
  end

  test "resolves the database-backed default for a workspace without touching the filesystem" do
    workspace = create_user_with_workspace.workspaces.first

    Dir.mktmpdir do |dir|
      # An unrelated filesystem default must be ignored when a workspace is given.
      Pathname.new(dir).join("default").mkpath
      Pathname.new(dir).join("default", "instructions.md").write("Filesystem instructions.")

      transformer = Nodl::Transformation::TransformerRepository.new(root_path: dir).fetch("default", workspace: workspace)

      assert_includes transformer.instructions, "well-structured Markdown"
      assert_equal [ "example.md" ], transformer.templates.map(&:name)
    end
  end

  test "raises when a workspace has no profile for the handle" do
    workspace = create_user_with_workspace.workspaces.first

    error = assert_raises(Nodl::ValidationError) do
      Nodl::Transformation::TransformerRepository.new.fetch("missing", workspace: workspace)
    end

    assert_includes error.message, "Transformer not found: missing"
  end
end
