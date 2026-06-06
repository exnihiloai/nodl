class PlanLimits
  MAX_RECORDINGS = 8
  MAX_FORMATS = 5
  MAX_RECORDING_DURATION = 1.hour

  def self.max_recording_duration_seconds
    MAX_RECORDING_DURATION.to_i
  end
end
