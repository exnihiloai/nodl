require "nodl/providers/gemini_client"

class RecordingTitleGenerator
  DEFAULT_MODEL = "gemini-3.1-flash-lite".freeze
  MAX_TITLE_LENGTH = 80

  PROMPT = <<~PROMPT.freeze
    Create a concise, meaningful title for this audio transcript.

    Requirements:
    - Use the transcript's main language.
    - Prefer a concrete topic over a generic label.
    - Use title case only when it fits the language.
    - Do not include speaker labels, quotation marks, Markdown, or punctuation at the end.
    - Return only the title.
    - Maximum 8 words.
  PROMPT

  def initialize(client: Nodl::Providers::GeminiClient.new)
    @client = client
  end

  def generate(transcript:)
    # A recording with no speech has an empty transcript. Asking the model to
    # title nothing makes it reply with a meta-response ("Please provide the
    # transcript..."), so skip the call and let the caller keep its default
    # title instead.
    return if transcript.to_s.strip.blank?

    title = client.generate_text(
      model: ENV.fetch("NODL_GEMINI_TITLE_MODEL", DEFAULT_MODEL),
      parts: [ { text: "#{PROMPT}\n\nTranscript:\n#{transcript}" } ],
      generation_config: { temperature: 0.2 }
    )

    sanitize(title)
  end

  private

  attr_reader :client

  def sanitize(title)
    title.to_s
      .lines
      .first
      .to_s
      .strip
      .delete_prefix("#")
      .strip
      .delete_prefix('"')
      .delete_suffix('"')
      .delete_prefix("'")
      .delete_suffix("'")
      .sub(/[.!?]\z/, "")
      .truncate(MAX_TITLE_LENGTH, omission: "")
      .strip
      .presence
  end
end
