require "pathname"
require_relative "error"

module Nodl
  class AudioInput
    SUPPORTED_MIME_TYPES = {
      ".mp3" => "audio/mpeg"
    }.freeze

    attr_reader :path

    def initialize(path)
      @path = Pathname.new(path.to_s).expand_path
      validate!
    end

    def mime_type
      SUPPORTED_MIME_TYPES.fetch(extension)
    end

    def basename
      path.basename.to_s
    end

    def slug
      path.basename(extension).to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "").presence || "audio"
    end

    private

    def validate!
      raise ValidationError, "Audio file path is required." if path.to_s.blank?
      raise ValidationError, "Audio file does not exist: #{path}" unless path.file?
      raise ValidationError, "Audio file is not readable: #{path}" unless path.readable?

      return if SUPPORTED_MIME_TYPES.key?(extension)

      raise ValidationError, "Unsupported audio file type #{extension.inspect}. Only .mp3 is supported."
    end

    def extension
      path.extname.downcase
    end
  end
end
