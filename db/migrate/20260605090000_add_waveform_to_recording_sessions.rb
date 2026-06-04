class AddWaveformToRecordingSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :recording_sessions, :waveform_peaks, :jsonb
    add_column :recording_sessions, :audio_duration, :float
  end
end
