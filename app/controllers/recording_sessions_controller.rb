class RecordingSessionsController < ApplicationController
  include ActiveStorage::Streaming

  require "json"
  require "stringio"
  require "zip"
  require "nodl/integrity/recording_integrity_service"

  before_action :authenticate_user!
  before_action :require_workspace!

  def create
    @recording_session = @workspace.recording_sessions.build(recording_session_params)
    @recording_session.creator = current_user
    @recording_session.transformer_handle = selected_transformer_handle
    @recording_session.status = :recording if microphone_recording_start?

    if @recording_session.save
      if @recording_session.recording?
        render json: recording_session_payload(@recording_session), status: :created
      else
        ProcessRecordingSessionJob.perform_later(@recording_session.id)
        enqueue_integrity_sealing(@recording_session)
        redirect_to dashboard_path, notice: t("flash.recording_sessions.created")
      end
    else
      respond_to do |format|
        format.json { render json: { error: @recording_session.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        format.html { redirect_to dashboard_path, alert: @recording_session.errors.full_messages.to_sentence }
      end
    end
  end

  def show
    @recording_session = current_workspace.recording_sessions.includes(:creator, :document, :integrity_record, original_audio_attachment: :blob, normalized_audio_attachment: :blob).find(params[:id])
    @document = @recording_session.document
  end

  def destroy
    recording_session = current_workspace.recording_sessions.finalized.find_by(id: params[:id])
    return handle_missing_destroy unless recording_session

    title = recording_session.title
    if recording_session.destroy
      respond_to_destroy(:notice, t("flash.recording_sessions.deleted", title: title), status: :see_other)
    else
      respond_to_destroy(:alert, t("flash.recording_sessions.delete_failed", title: title), status: :unprocessable_entity)
    end
  end

  def finalize
    @recording_session = current_workspace.recording_sessions.find(params[:id])
    return render json: { error: t("flash.recording_sessions.not_ready_to_finalize") }, status: :unprocessable_entity unless @recording_session.recording?

    @recording_session.assign_attributes(recording_session_params)
    @recording_session.status = :processing
    @recording_session.error_message = nil
    @recording_session.processing_started_at = Time.current
    @recording_session.processing_completed_at = nil

    if @recording_session.save
      ProcessRecordingSessionJob.perform_later(@recording_session.id)
      enqueue_integrity_sealing(@recording_session)
      render json: { status: @recording_session.status, url: recording_session_path(@recording_session) }, status: :accepted
    else
      render json: { error: @recording_session.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def download_original_audio
    recording_session = current_workspace.recording_sessions.includes(original_audio_attachment: :blob).find(params[:id])
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.original_audio_unavailable") unless recording_session.original_audio.attached?
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.original_audio_not_ready") unless recording_session.original_audio_downloadable?
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.original_audio_unavailable") unless original_audio_stored?(recording_session)

    stream_original_audio(recording_session)
  end

  def download_integrity_archive
    recording_session = current_workspace.recording_sessions.includes(:integrity_record, original_audio_attachment: :blob).find(params[:id])
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.integrity_archive_unavailable") unless recording_session.creator.integrity_sealing_enabled?
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.original_audio_unavailable") unless recording_session.original_audio.attached?
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.original_audio_not_ready") unless recording_session.original_audio_downloadable?
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.original_audio_unavailable") unless original_audio_stored?(recording_session)
    return redirect_to recording_session_path(recording_session), alert: t("flash.recording_sessions.integrity_archive_unavailable") unless recording_session.integrity_record&.sealed?

    send_integrity_archive(recording_session)
  end

  private

  def handle_missing_destroy
    raise ActiveRecord::RecordNotFound if RecordingSession.exists?(id: params[:id])

    respond_to_destroy(:notice, t("flash.recording_sessions.already_deleted"), status: :see_other)
  end

  def respond_to_destroy(type, message, status:)
    if redirect_after_destroy?
      redirect_to dashboard_path, { type => message, status: :see_other }
      return
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[type] = message
        render turbo_stream: [
          turbo_stream.replace(
            "dashboard_activity",
            partial: "dashboard/activity",
            locals: { recording_sessions: dashboard_recording_sessions }
          ),
          turbo_stream.replace("flash", partial: "shared/flash")
        ], status: status
      end
      format.html { redirect_to dashboard_path, { type => message, status: :see_other } }
    end
  end

  def redirect_after_destroy?
    ActiveModel::Type::Boolean.new.cast(params[:redirect_to_dashboard])
  end

  def dashboard_recording_sessions
    current_workspace.recording_sessions.finalized.includes(:document, original_audio_attachment: :blob).recent_first.limit(RecordingSession::DASHBOARD_RECENT_LIMIT)
  end

  def enqueue_integrity_sealing(recording_session)
    return unless recording_session.creator.integrity_sealing_enabled?
    return unless recording_session.original_audio.attached?

    SealRecordingIntegrityJob.perform_later(recording_session.id)
  end

  def recording_session_params
    params.require(:recording_session).permit(:title, :source_kind, :original_audio, :time_zone)
  end

  def selected_transformer_handle
    handle = params.require(:recording_session).permit(:transformer_handle).fetch(:transformer_handle, TransformerProfile::DEFAULT_HANDLE)
    current_workspace.transformer_profiles.active.find_by(handle: handle)&.handle || TransformerProfile::DEFAULT_HANDLE
  end

  def microphone_recording_start?
    recording_session_params[:source_kind] == "microphone" && !recording_session_params[:original_audio].present?
  end

  def original_audio_stored?(recording_session)
    blob = recording_session.original_audio.blob
    blob.service.exist?(blob.key)
  rescue ActiveStorage::FileNotFoundError
    false
  end

  def stream_original_audio(recording_session)
    blob = recording_session.original_audio.blob
    response.headers["Accept-Ranges"] = "bytes"
    response.headers["Content-Length"] = blob.byte_size.to_s

    send_stream(
      filename: recording_session.original_audio_download_filename,
      disposition: "attachment",
      type: blob.content_type
    ) do |stream|
      blob.download { |chunk| stream.write(chunk) }
    end
  end

  def send_integrity_archive(recording_session)
    audio_bytes = recording_session.original_audio.download
    audio_filename = recording_session.original_audio_download_filename
    certificate = Nodl::Integrity::RecordingIntegrityService.certificate_payload(recording_session, audio_bytes: audio_bytes)
    archive = Zip::OutputStream.write_buffer(StringIO.new) do |zip|
      zip.put_next_entry(audio_filename)
      zip.write(audio_bytes)
      zip.put_next_entry("integrity-certificate.json")
      zip.write(JSON.pretty_generate(certificate))
    end
    archive.rewind

    send_data archive.string,
      filename: integrity_archive_filename(recording_session),
      type: "application/zip",
      disposition: "attachment"
  end

  def integrity_archive_filename(recording_session)
    basename = File.basename(recording_session.original_audio_download_filename, ".*").parameterize.presence || "recording"
    "#{basename}-integrity-archive.zip"
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
