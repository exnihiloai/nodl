class RecordingSessionsController < ApplicationController
  before_action :authenticate_user!

  def create
    @workspace = current_workspace
    return redirect_to dashboard_path, alert: "No workspace is available." unless @workspace

    @recording_session = @workspace.recording_sessions.build(recording_session_params)
    @recording_session.creator = current_user
    @recording_session.transformer_handle = selected_transformer_handle

    if @recording_session.save
      ProcessRecordingSessionJob.perform_later(@recording_session.id)
      redirect_to dashboard_path, notice: "Recording session created. Processing has started."
    else
      redirect_to dashboard_path, alert: @recording_session.errors.full_messages.to_sentence
    end
  end

  def show
    @recording_session = current_workspace.recording_sessions.includes(:document, original_audio_attachment: :blob).find(params[:id])
    @document = @recording_session.document
  end

  private

  def recording_session_params
    params.require(:recording_session).permit(:title, :source_kind, :original_audio)
  end

  def selected_transformer_handle
    handle = params.require(:recording_session).permit(:transformer_handle).fetch(:transformer_handle, TransformerProfile::DEFAULT_HANDLE)
    current_workspace.transformer_profiles.active.find_by(handle: handle)&.handle || TransformerProfile::DEFAULT_HANDLE
  end
end
