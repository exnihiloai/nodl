class DocumentsController < ApplicationController
  before_action :authenticate_user!

  def show
    @document = current_workspace.documents.includes(:recording_session).find(params[:id])
    @recording_session = @document.recording_session
  end
end
