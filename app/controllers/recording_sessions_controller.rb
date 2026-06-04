class RecordingSessionsController < ApplicationController
  before_action :authenticate_user!

  def create
    @workspace = current_workspace
    return redirect_to dashboard_path, alert: "No workspace is available." unless @workspace

    @recording_session = @workspace.recording_sessions.build(recording_session_params)
    @recording_session.creator = current_user
    @recording_session.transformer_handle = selected_transformer_handle
    @recording_session.status = :recording if microphone_recording_start?

    if @recording_session.save
      if @recording_session.recording?
        render json: recording_session_payload(@recording_session), status: :created
      else
        ProcessRecordingSessionJob.perform_later(@recording_session.id)
        redirect_to dashboard_path, notice: "Recording session created. Processing has started."
      end
    else
      respond_to do |format|
        format.json { render json: { error: @recording_session.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        format.html { redirect_to dashboard_path, alert: @recording_session.errors.full_messages.to_sentence }
      end
    end
  end

  def show
    @recording_session = current_workspace.recording_sessions.includes(:document, original_audio_attachment: :blob, normalized_audio_attachment: :blob).find(params[:id])
    @document = @recording_session.document
  end

  def finalize
    @recording_session = current_workspace.recording_sessions.find(params[:id])
    return render json: { error: "Recording session is not ready to finalize." }, status: :unprocessable_entity unless @recording_session.recording?

    @recording_session.assign_attributes(recording_session_params)
    @recording_session.status = :processing
    @recording_session.error_message = nil
    @recording_session.processing_started_at = Time.current
    @recording_session.processing_completed_at = nil

    if @recording_session.save
      ProcessRecordingSessionJob.perform_later(@recording_session.id)
      render json: { status: @recording_session.status, url: recording_session_path(@recording_session) }, status: :accepted
    else
      render json: { error: @recording_session.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def recording_session_params
    params.require(:recording_session).permit(:title, :source_kind, :original_audio)
  end

  def selected_transformer_handle
    handle = params.require(:recording_session).permit(:transformer_handle).fetch(:transformer_handle, TransformerProfile::DEFAULT_HANDLE)
    current_workspace.transformer_profiles.active.find_by(handle: handle)&.handle || TransformerProfile::DEFAULT_HANDLE
  end

  def microphone_recording_start?
    recording_session_params[:source_kind] == "microphone" && !recording_session_params[:original_audio].present?
  end

  def recording_session_payload(recording_session)
    {
      id: recording_session.id,
      status: recording_session.status,
      finalize_url: finalize_recording_session_path(recording_session),
      realtime_channel: "LiveTranscriptionChannel",
      live_stream_name: Turbo::StreamsChannel.signed_stream_name(recording_session.live_stream)
    }
  end
end
