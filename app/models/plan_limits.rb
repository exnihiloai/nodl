class PlanLimits
  MAX_RECORDING_DURATION = 1.hour

  def self.max_recording_duration_seconds
    MAX_RECORDING_DURATION.to_i
  end
end
