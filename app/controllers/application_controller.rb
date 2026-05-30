class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :current_workspace, :user_signed_in?

  private

  def current_user
    return @current_user if defined?(@current_user)

    user_id = session[:user_id]
    @current_user = user_id ? User.find_by(id: user_id) : nil
  end

  def user_signed_in?
    current_user.present?
  end

  def current_workspace
    return nil unless current_user

    workspace = current_user.workspaces.find_by(id: session[:current_workspace_id])
    workspace ||= current_user.workspaces.order("memberships.created_at ASC").first
    session[:current_workspace_id] = workspace.id if workspace
    workspace
  end

  def authenticate_user!
    return if current_user

    redirect_to login_path, alert: "Please sign in to continue."
  end

  def require_admin!
    return if current_user&.admin?

    redirect_to dashboard_path, alert: "You are not authorized for this section."
  end
end
