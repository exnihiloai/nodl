require "test_helper"
require "tmpdir"
require "open3"
require "nodl/audio/waveform_extractor"

class NodlWaveformExtractorTest < ActiveSupport::TestCase
  test "computes normalized peaks and duration from real audio" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "tone.wav")
      _out, _err, status = Open3.capture3(
        "ffmpeg", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=2", path
      )
      assert status.success?, "ffmpeg failed to generate the test tone"

      result = Nodl::Audio::WaveformExtractor.new.extract(path, buckets: 64)

      assert_equal 64, result.peaks.length
      assert result.peaks.all? { |peak| peak >= 0.0 && peak <= 1.0 }, "peaks must be normalized to 0..1"
      assert_equal 1.0, result.peaks.max, "loudest bucket should normalize to 1.0"
      assert_in_delta 2.0, result.duration, 0.3
    end
  end

  test "returns empty peaks for unreadable audio instead of raising" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "bad.mp3")
      File.binwrite(path, "this is not audio")

      result = Nodl::Audio::WaveformExtractor.new.extract(path)

      assert_empty result.peaks
      assert_equal 0.0, result.duration
    end
  end
end
