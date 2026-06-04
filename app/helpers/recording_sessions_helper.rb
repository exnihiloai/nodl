module RecordingSessionsHelper
  # Distinct, reasonably color-blind-friendly palette. Orange/purple first to
  # echo the player the design references.
  SPEAKER_PALETTE = %w[#f97316 #a855f7 #0ea5e9 #10b981 #ef4444 #eab308 #ec4899 #14b8a6].freeze

  # Speakers in order of first appearance across the structured segments.
  def transcript_speakers(segments)
    Array(segments).filter_map { |segment| segment["speaker"].presence }.uniq
  end

  def multi_speaker_transcript?(segments)
    transcript_speakers(segments).size > 1
  end

  # Map of speaker label => hex color, assigned by appearance order.
  def speaker_color_map(segments)
    transcript_speakers(segments).each_with_index.to_h do |speaker, index|
      [ speaker, SPEAKER_PALETTE[index % SPEAKER_PALETTE.size] ]
    end
  end

  SPEAKER_LABEL = /\Aspeaker[\s_-]*\d+\s*:?\s*/i

  # Removes a leading "speaker_1:" / "Speaker 1:" label that Voxtral prepends to
  # diarized segment text.
  def strip_speaker_label(text)
    text.to_s.strip.sub(SPEAKER_LABEL, "").strip
  end

  # Structured segments reduced to what the audio player needs for waveform
  # tinting and time->text mapping.
  def transcript_timeline(segments)
    Array(segments).filter_map do |segment|
      start = segment["start"]
      finish = segment["end"]
      next if start.nil? || finish.nil?

      { "start" => start.to_f, "end" => finish.to_f, "speaker" => segment["speaker"].presence }
    end
  end
end
