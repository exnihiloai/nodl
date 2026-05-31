require "test_helper"
require "tmpdir"
require "nodl/audio/normalizer"

class NodlAudioNormalizerTest < ActiveSupport::TestCase
  test "returns mp3 input directly" do
    path = Rails.root.join("test", "fixtures", "files", "sample.mp3")

    result = Nodl::Audio::Normalizer.new.normalize(
      input_path: path,
      content_type: "audio/mpeg",
      original_filename: "sample.mp3"
    )

    assert_not result.converted?
    assert_equal path.expand_path, result.path
  end

  test "converts browser audio with ffmpeg" do
    Dir.mktmpdir do |dir|
      input = Pathname.new(dir).join("recording.webm")
      input.write("webm bytes")
      normalizer = Nodl::Audio::Normalizer.new(ffmpeg_path: "ffmpeg")

      Open3.expects(:capture3).with do |*command|
        output_path = command.last
        File.binwrite(output_path, "mp3 bytes")
        command.first == "ffmpeg" && command.include?(input.to_s)
      end.returns([ "", "", stub(success?: true) ])

      result = normalizer.normalize(
        input_path: input,
        content_type: "audio/webm;codecs=opus",
        original_filename: "recording.webm"
      )

      assert_predicate result, :converted?
      assert_equal "audio/mpeg", result.content_type
      assert_equal "mp3 bytes", result.path.binread
    ensure
      FileUtils.rm_f(result.path) if result&.converted?
    end
  end

  test "raises a clear error for unsupported input" do
    error = assert_raises(Nodl::ValidationError) do
      Nodl::Audio::Normalizer.new.normalize(
        input_path: Rails.root.join("README.md"),
        content_type: "text/plain",
        original_filename: "README.md"
      )
    end

    assert_includes error.message, "Unsupported audio format"
  end
end
