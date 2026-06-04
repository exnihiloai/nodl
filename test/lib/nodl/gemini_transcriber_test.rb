require "test_helper"
require "nodl/transcription/gemini_transcriber"

class NodlGeminiTranscriberTest < ActiveSupport::TestCase
  test "prompt asks for speaker tags when multiple speakers are present" do
    assert_includes Nodl::Transcription::GeminiTranscriber::PROMPT, "If there are multiple speakers"
    assert_includes Nodl::Transcription::GeminiTranscriber::PROMPT, "speaker tags"
  end
end
