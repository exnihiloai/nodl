class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @workspace = current_workspace
    if @workspace
      TransformerProfile.ensure_default_for!(@workspace)
      @transformer_profiles = @workspace.transformer_profiles.active.default_first
      @recording_sessions = @workspace.recording_sessions.finalized.includes(:document, original_audio_attachment: :blob).recent_first.limit(8)
      @recording_session = @workspace.recording_sessions.build(transformer_handle: default_transformer_handle)
      @recording_limit_reached = @workspace.recording_limit_reached?
      @format_limit_reached = @workspace.format_limit_reached?
    else
      @transformer_profiles = TransformerProfile.none
      @recording_sessions = RecordingSession.none
      @recording_session = RecordingSession.new
      @recording_limit_reached = false
      @format_limit_reached = false
    end
  end

  private

  def default_transformer_handle
    @workspace.transformer_profiles.find_by(default: true)&.handle || TransformerProfile::DEFAULT_HANDLE
  end
end
