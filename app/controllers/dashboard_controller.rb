class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @workspace = current_workspace
    @memberships = current_user.memberships.includes(:workspace).order(:created_at)
    if @workspace
      TransformerProfile.ensure_default_for!(@workspace)
      @transformer_profiles = @workspace.transformer_profiles.active.default_first
      @recording_sessions = @workspace.recording_sessions.includes(:document, original_audio_attachment: :blob).recent_first.limit(8)
      @documents = @workspace.documents.includes(:recording_session).recent_first.limit(8)
      @recording_session = @workspace.recording_sessions.build(transformer_handle: default_transformer_handle)
    else
      @transformer_profiles = TransformerProfile.none
      @recording_sessions = RecordingSession.none
      @documents = Document.none
      @recording_session = RecordingSession.new
    end
  end

  private

  def default_transformer_handle
    @workspace.transformer_profiles.find_by(default: true)&.handle || TransformerProfile::DEFAULT_HANDLE
  end
end
