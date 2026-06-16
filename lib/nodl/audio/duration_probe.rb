require "tempfile"
require "nodl/audio/waveform_extractor"

module Nodl
  module Audio
    class DurationProbe
      def initialize(attachment:, attachment_change: nil, extractor: WaveformExtractor.new)
        @attachment = attachment
        @attachment_change = attachment_change
        @extractor = extractor
      end

      def duration
        if attachment_change
          measure_pending_attachable
        else
          measure_persisted_attachment
        end
      rescue Nodl::Error, ActiveStorage::FileNotFoundError
        nil
      end

      private

      attr_reader :attachment, :attachment_change, :extractor

      def measure_pending_attachable
        attachable = attachment_change.attachable
        path = attachable_path(attachable)
        return extractor.extract(path).duration if path.present?

        io = attachable_io(attachable)
        return unless io

        with_temp_audio_file { |file| copy_io(io, file) }
      end

      def measure_persisted_attachment
        with_temp_audio_file { |file| file.write(attachment.download) }
      end

      def with_temp_audio_file
        Tempfile.create([ "recording-duration", extension ], binmode: true) do |file|
          yield file
          file.flush
          return extractor.extract(file.path).duration
        end
      end

      def attachable_path(attachable)
        io = attachable_io(attachable)
        return unless io.respond_to?(:path)

        path = io.path.to_s
        path if path.present? && File.exist?(path)
      end

      def attachable_io(attachable)
        return attachable[:io] || attachable["io"] if attachable.is_a?(Hash)
        return attachable.tempfile if attachable.respond_to?(:tempfile)

        attachable if attachable.respond_to?(:read)
      end

      def copy_io(io, file)
        position = io.pos if io.respond_to?(:pos)
        io.rewind if io.respond_to?(:rewind)
        file.write(io.read)
      ensure
        io.seek(position) if position && io.respond_to?(:seek)
      end

      def extension
        attachment.filename.extension_with_delimiter.presence || ".audio"
      end
    end
  end
end
