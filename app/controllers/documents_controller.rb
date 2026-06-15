class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_workspace!

  def show
    load_document
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
