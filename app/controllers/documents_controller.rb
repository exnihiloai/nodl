class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_workspace!

  def show
    @document = current_workspace.documents.includes(:recording_session).find(params[:id])
    @recording_session = @document.recording_session
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
end
