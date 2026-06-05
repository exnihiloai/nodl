require "test_helper"

class DocumentTextExtractorTest < ActiveSupport::TestCase
  EXPECTED_PHRASE = "Quarterly planning highlights".freeze

  CONTENT_TYPES = {
    "txt" => "text/plain",
    "md" => "text/markdown",
    "pdf" => "application/pdf",
    "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "odt" => "application/vnd.oasis.opendocument.text"
  }.freeze

  CONTENT_TYPES.each do |extension, content_type|
    test "extracts text from #{extension} documents" do
      profile = build_profile_with_example("example.#{extension}", content_type)

      text = DocumentTextExtractor.extract(profile.example_files.first)

      assert_includes text, EXPECTED_PHRASE
    end
  end

  test "returns empty string for an unattached attachment" do
    profile = TransformerProfile.new

    assert_equal "", DocumentTextExtractor.extract(profile.example_files.first)
    assert_equal "", DocumentTextExtractor.extract(nil)
  end

  test "returns empty string and logs when extraction fails" do
    profile = build_profile_with_example("example.txt", "text/plain")
    PDF::Reader.stubs(:new).raises(StandardError, "boom")
    # Force the PDF branch on a non-PDF blob to exercise the rescue path.
    profile.example_files.first.blob.update!(content_type: "application/pdf")

    assert_equal "", DocumentTextExtractor.extract(profile.example_files.first)
  end

  private

  def build_profile_with_example(filename, content_type)
    workspace = create_user_with_workspace.workspaces.first
    profile = workspace.transformer_profiles.create!(
      name: "Example",
      handle: "example-#{SecureRandom.hex(3)}",
      instructions: "Guidelines."
    )
    profile.example_files.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", filename)),
      filename: filename,
      content_type: content_type
    )
    profile
  end
end
