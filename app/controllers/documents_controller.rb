class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_workspace!

  def show
    load_document
    @export_wall = current_workspace.on_trial? && current_workspace.entitlement_for(:exports).denied?
  end

  def update
    load_document

    if @document.update(document_params)
      redirect_to document_path(@document), notice: t("flash.documents.updated")
    else
      @editing = true
      render :show, status: :unprocessable_entity
    end
  end

  def download
    document = current_workspace.documents.find(params[:id])
    exporter = DocumentExporters.for(params[:format], document)
    entitlement = current_workspace.entitlement_for(:exports)
    unless entitlement.allowed?
      redirect_to document_path(document), alert: t("flash.entitlements.limit_reached", limit: entitlement.limit)
      return
    end

    UsageRecorder.record!(
      workspace: current_workspace,
      user: current_user,
      event_kind: "document_exported",
      subject: document,
      metadata: { format: params[:format].to_s }
    )
    send_data exporter.render,
              filename: exporter.filename,
              type: exporter.content_type,
              disposition: "attachment"
  rescue DocumentExporters::UnsupportedFormatError
    head :bad_request
  end

  private

  def load_document
    @document = current_workspace.documents.includes(:recording_session).find(params[:id])
    @recording_session = @document.recording_session
  end

  def document_params
    params.require(:document).permit(:content)
  end
end
