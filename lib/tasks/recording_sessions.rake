require "tempfile"
require "nodl/audio/waveform_extractor"

namespace :recording_sessions do
  desc "Backfill waveform peaks + duration for completed recordings that are missing them"
  task backfill_waveforms: :environment do
    extractor = Nodl::Audio::WaveformExtractor.new
    scope = RecordingSession.completed.where(waveform_peaks: nil)
    puts "Backfilling #{scope.count} recording session(s)…"

    scope.find_each do |session|
      audio = session.playback_audio
      unless audio.attached?
        puts "  skip ##{session.id} (no audio attached)"
        next
      end

      extension = audio.filename.extension_with_delimiter.presence || ".audio"
      Tempfile.create([ "waveform-#{session.id}", extension ], binmode: true) do |file|
        file.write(audio.download)
        file.flush
        result = extractor.extract(file.path)
        session.update!(waveform_peaks: result.peaks, audio_duration: result.duration)
        puts "  ok   ##{session.id} peaks=#{result.peaks.size} duration=#{result.duration}"
      end
    rescue StandardError => error
      puts "  fail ##{session.id}: #{error.message}"
    end
  end
end
