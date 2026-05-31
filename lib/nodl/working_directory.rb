require "fileutils"
require "pathname"
require "securerandom"
require "time"

module Nodl
  class WorkingDirectory
    Session = Struct.new(:path, keyword_init: true) do
      def audio_path
        path.join("audio.mp3")
      end

      def transcript_path
        path.join("transcript.md")
      end

      def document_path
        path.join("document.md")
      end

      def metadata_path
        path.join("metadata.json")
      end
    end

    attr_reader :root_path

    def initialize(root_path: Rails.root.join("work", "sessions"))
      @root_path = Pathname.new(root_path.to_s)
    end

    def create_session(audio_input, now: Time.now.utc)
      session = Session.new(path: root_path.join(run_id_for(audio_input, now: now)))
      FileUtils.mkdir_p(session.path)
      session
    end

    private

    def run_id_for(audio_input, now:)
      timestamp = now.utc.strftime("%Y%m%d%H%M%S")
      "#{timestamp}-#{audio_input.slug}-#{SecureRandom.hex(4)}"
    end
  end
end
