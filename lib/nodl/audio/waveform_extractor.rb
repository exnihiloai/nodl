require "open3"
require "pathname"
require_relative "../error"

module Nodl
  module Audio
    # Precomputes a compact loudness envelope (a small array of normalized peak
    # values, 0..1) plus the duration for an audio file, so the client can draw
    # the waveform instantly without downloading and decoding the whole file.
    class WaveformExtractor
      DEFAULT_BUCKETS = 320
      SAMPLE_RATE = 2000 # plenty of resolution for a few hundred bars; keeps work small
      READ_CHUNK = 65_536

      Result = Struct.new(:peaks, :duration, keyword_init: true)

      def initialize(ffmpeg_path: ENV.fetch("FFMPEG_PATH", "ffmpeg"), ffprobe_path: ENV.fetch("FFPROBE_PATH", "ffprobe"))
        @ffmpeg_path = ffmpeg_path
        @ffprobe_path = ffprobe_path
      end

      def extract(path, buckets: DEFAULT_BUCKETS)
        path = Pathname.new(path.to_s)
        duration = probe_duration(path)
        return Result.new(peaks: [], duration: 0.0) unless duration&.positive?

        peaks = bucketed_peaks(path, duration: duration, buckets: buckets)
        Result.new(peaks: peaks, duration: duration.round(3))
      end

      private

      attr_reader :ffmpeg_path, :ffprobe_path

      def probe_duration(path)
        command = [
          ffprobe_path, "-v", "error",
          "-show_entries", "format=duration",
          "-of", "default=nokey=1:noprint_wrappers=1",
          path.to_s
        ]
        stdout, _stderr, status = Open3.capture3(*command)
        return nil unless status.success?

        value = stdout.strip.to_f
        value.positive? ? value : nil
      rescue Errno::ENOENT
        raise ConfigurationError, "ffprobe is required to compute the audio waveform."
      end

      def bucketed_peaks(path, duration:, buckets:)
        total_samples = (duration * SAMPLE_RATE).round
        return [] unless total_samples.positive?

        per_bucket = total_samples.to_f / buckets
        sums = Array.new(buckets, 0.0)
        counts = Array.new(buckets, 0)
        index = 0
        leftover = "".b

        run_decoder(path) do |chunk|
          data = leftover.empty? ? chunk : (leftover + chunk)
          usable = data.bytesize - (data.bytesize % 2)
          leftover = usable < data.bytesize ? data.byteslice(usable, data.bytesize - usable) : "".b
          next if usable.zero?

          data.byteslice(0, usable).unpack("s<*").each do |sample|
            bucket = (index / per_bucket).to_i
            bucket = buckets - 1 if bucket >= buckets
            sums[bucket] += sample.to_f * sample
            counts[bucket] += 1
            index += 1
          end
        end

        normalize(sums, counts)
      end

      def run_decoder(path)
        command = [
          ffmpeg_path, "-v", "error",
          "-i", path.to_s,
          "-ac", "1", "-ar", SAMPLE_RATE.to_s,
          "-f", "s16le", "-"
        ]
        Open3.popen3(*command) do |stdin, stdout, stderr, wait_thread|
          stdin.close
          stdout.binmode
          while (chunk = stdout.read(READ_CHUNK))
            yield chunk
          end
          error = stderr.read
          raise ValidationError, "ffmpeg waveform extraction failed: #{error.strip}" unless wait_thread.value.success?
        end
      rescue Errno::ENOENT
        raise ConfigurationError, "ffmpeg is required to compute the audio waveform."
      end

      def normalize(sums, counts)
        rms = sums.each_with_index.map do |sum, i|
          counts[i].positive? ? Math.sqrt(sum / counts[i]) : 0.0
        end
        max = rms.max.to_f
        return rms.map { 0.0 } unless max.positive?

        rms.map { |value| (value / max).round(4) }
      end
    end
  end
end
