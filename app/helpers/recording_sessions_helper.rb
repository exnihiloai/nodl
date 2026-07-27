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

  # Consecutive segments from the same speaker become a single readable turn.
  # Speaker numbers follow first appearance so they match the on-page legend.
  def transcript_speaker_turns(segments)
    speaker_numbers = transcript_speakers(segments).each_with_index.to_h { |speaker, index| [ speaker, index + 1 ] }

    Array(segments).chunk { |segment| segment["speaker"].presence || false }.filter_map do |speaker, run|
      speaker = nil unless speaker
      text = run.filter_map { |segment| strip_speaker_label(segment["text"]).presence }.join(" ")
      next if text.blank?

      { speaker: speaker, number: speaker_numbers[speaker], text: text }
    end
  end

  def annotated_transcript_plain_text(segments)
    return unless multi_speaker_transcript?(segments)

    transcript_speaker_turns(segments).map { |turn| annotated_transcript_turn_text(turn) }.join("\n\n")
  end

  def annotated_transcript_html(segments)
    return unless multi_speaker_transcript?(segments)

    transcript_speaker_turns(segments).map do |turn|
      tag.p do
        if turn[:number]
          safe_join([ tag.strong("[#{transcript_speaker_label(turn[:number])}]"), " ", turn[:text] ])
        else
          turn[:text]
        end
      end
    end.join
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

  def integrity_status_key(integrity_record)
    integrity_record&.tsa_status || "pending"
  end

  def integrity_badge_class(integrity_record)
    case integrity_status_key(integrity_record)
    when RecordingIntegrityRecord::STATUS_SEALED
      "badge-success"
    when RecordingIntegrityRecord::STATUS_FAILED
      "badge-warning"
    when RecordingIntegrityRecord::STATUS_PENDING_CONFIG
      "badge-info"
    else
      "badge-neutral"
    end
  end

  def recording_delete_confirm(recording_session)
    t("recording_sessions.actions.delete_confirm", title: recording_session.title)
  end

  private

  def annotated_transcript_turn_text(turn)
    return turn[:text] unless turn[:number]

    "[#{transcript_speaker_label(turn[:number])}] #{turn[:text]}"
  end

  def transcript_speaker_label(number)
    t("recording_sessions.interactive.speaker", number: number)
  end
end
