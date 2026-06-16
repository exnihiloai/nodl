require "open3"
require "pathname"
require "securerandom"
require "tmpdir"
require_relative "../error"

module Nodl
  module Audio
    class Normalizer
      INVALID_AUDIO_MESSAGE = "The recording was interrupted before a valid audio file could be saved. Please try recording again.".freeze

      Result = Struct.new(:path, :converted, :content_type, :filename, keyword_init: true) do
        def converted?
          converted
        end
      end

      DIRECT_EXTENSIONS = %w[.mp3].freeze
      DIRECT_CONTENT_TYPES = %w[audio/mp3 audio/mpeg].freeze
      CONVERTIBLE_EXTENSIONS = %w[.aac .flac .m4a .mp4 .oga .ogg .wav .webm].freeze
      CONVERTIBLE_CONTENT_TYPES = %w[
        audio/aac
        audio/flac
        audio/mp4
        audio/ogg
        audio/wav
        audio/webm
        video/mp4
        video/webm
      ].freeze

      def initialize(ffmpeg_path: ENV.fetch("FFMPEG_PATH", "ffmpeg"))
        @ffmpeg_path = ffmpeg_path
      end

      def normalize(input_path:, content_type:, original_filename:)
        input = Pathname.new(input_path.to_s)
        normalized_content_type = normalize_content_type(content_type)
        extension = extension_for(input, original_filename)

        return direct_result(input) if direct_audio?(extension, normalized_content_type)
        raise ValidationError, "Unsupported audio format for normalization." unless convertible_audio?(extension, normalized_content_type)

        output_path = Pathname.new(Dir.tmpdir).join("#{input.basename(extension).to_s.presence || "recording"}-#{SecureRandom.hex(8)}.mp3")

        convert!(input, output_path)
        Result.new(path: output_path, converted: true, content_type: "audio/mpeg", filename: "#{input.basename(extension)}.mp3")
      end

      private

      attr_reader :ffmpeg_path

      def direct_audio?(extension, content_type)
        DIRECT_EXTENSIONS.include?(extension) || DIRECT_CONTENT_TYPES.include?(content_type)
      end

      def convertible_audio?(extension, content_type)
        CONVERTIBLE_EXTENSIONS.include?(extension) || CONVERTIBLE_CONTENT_TYPES.include?(content_type)
      end

      def direct_result(input)
        Result.new(path: input, converted: false, content_type: "audio/mpeg", filename: input.basename.to_s)
      end

      def convert!(input, output_path)
        command = [
          ffmpeg_path,
          "-y",
          "-hide_banner",
          "-v", "error",
          "-i", input.to_s,
          "-vn",
          "-ac", "1",
          "-ar", "16000",
          "-b:a", "64k",
          output_path.to_s
        ]
        _stdout, stderr, status = Open3.capture3(*command)
        return if status.success? && Pathname.new(output_path).size.positive?

        log_ffmpeg_failure(stderr)
        raise ValidationError, INVALID_AUDIO_MESSAGE
      rescue Errno::ENOENT
        raise ConfigurationError, "ffmpeg is required to process this audio format."
      end

      def log_ffmpeg_failure(stderr)
        return unless defined?(Rails)

        Rails.logger.warn(
          "Audio normalization failed with ffmpeg: " \
          "#{stderr.to_s.strip.presence || "conversion failed"}"
        )
      end

      def normalize_content_type(content_type)
        content_type.to_s.split(";").first.to_s.strip.downcase
      end

      def extension_for(input, original_filename)
        filename_extension = Pathname.new(original_filename.to_s).extname.downcase
        filename_extension.presence || input.extname.downcase
      end
    end
  end
end
