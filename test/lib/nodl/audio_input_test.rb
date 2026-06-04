require "test_helper"
require "nodl/audio_input"

class NodlAudioInputTest < ActiveSupport::TestCase
  test "accepts readable mp3 files" do
    input = Nodl::AudioInput.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"))

    assert_equal "audio/mpeg", input.mime_type
    assert_equal "sample.mp3", input.basename
    assert_equal "sample", input.slug
  end

  test "rejects unsupported extensions" do
    error = assert_raises(Nodl::ValidationError) do
      Nodl::AudioInput.new(Rails.root.join("README.md"))
    end

    assert_includes error.message, "Only .mp3 is supported"
  end

  test "rejects missing files" do
    error = assert_raises(Nodl::ValidationError) do
      Nodl::AudioInput.new(Rails.root.join("missing.mp3"))
    end

    assert_includes error.message, "does not exist"
  end
end
