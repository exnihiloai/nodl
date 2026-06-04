require "test_helper"
require "nodl/transcription/gemini_transcriber"

class NodlGeminiTranscriberTest < ActiveSupport::TestCase
  test "final prompt asks for stable speaker labels only when multiple speakers are present" do
    assert_includes Nodl::Transcription::GeminiTranscriber::PROMPT, "If there is only one speaker, do not add speaker labels"
    assert_includes Nodl::Transcription::GeminiTranscriber::PROMPT, "Speaker 1:"
    assert_includes Nodl::Transcription::GeminiTranscriber::PROMPT, "Keep each speaker number consistent"
  end

  test "preview prompt does not ask for speaker labels" do
    assert_includes Nodl::Transcription::GeminiTranscriber::PREVIEW_PROMPT, "Do not add speaker labels"
  end
end
