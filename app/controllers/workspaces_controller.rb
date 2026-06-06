class WorkspacesController < ApplicationController
  before_action :authenticate_user!

  def switch
    workspace = current_user.workspaces.find(params[:id])
    session[:current_workspace_id] = workspace.id

    redirect_to dashboard_path, notice: t("flash.workspaces.switched", name: workspace.name)
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: t("flash.workspaces.not_found")
  end
end
