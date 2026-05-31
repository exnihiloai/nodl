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
end
