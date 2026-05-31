require "test_helper"
require "tmpdir"

class NodlWorkingDirectoryTest < ActiveSupport::TestCase
  test "creates a timestamped session directory with expected paths" do
    Dir.mktmpdir do |dir|
      input = Nodl::AudioInput.new(Rails.root.join("test", "fixtures", "files", "sample.mp3"))
      working_directory = Nodl::WorkingDirectory.new(root_path: dir)

      session = working_directory.create_session(input, now: Time.utc(2026, 5, 31, 12, 30, 45))

      assert_predicate session.path, :directory?
      assert_match(/\A20260531123045-sample-[a-f0-9]{8}\z/, session.path.basename.to_s)
      assert_equal session.path.join("audio.mp3"), session.audio_path
      assert_equal session.path.join("transcript.md"), session.transcript_path
      assert_equal session.path.join("document.md"), session.document_path
      assert_equal session.path.join("metadata.json"), session.metadata_path
    end
  end
end
