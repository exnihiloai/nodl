require "test_helper"

class NodlGeminiTranscriberTest < ActiveSupport::TestCase
  test "prompt asks for speaker tags when multiple speakers are present" do
    assert_includes Nodl::Transcription::GeminiTranscriber::PROMPT, "If there are multiple speakers"
    assert_includes Nodl::Transcription::GeminiTranscriber::PROMPT, "speaker tags"
  end
end
