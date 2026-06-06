class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :current_workspace, :user_signed_in?

  around_action :switch_locale

  private

  # Resolve the active locale for every request and keep it scoped to the
  # request lifecycle so background threads are never affected.
  def switch_locale(&action)
    I18n.with_locale(current_locale, &action)
  end

  # Priority: explicit session choice, signed-in user preference, the browser's
  # Accept-Language header, then the application default.
  def current_locale
    candidate = session[:locale] || current_user&.preferred_language || locale_from_header
    supported_locale?(candidate) ? candidate.to_sym : I18n.default_locale
  end

  def locale_from_header
    request.env["HTTP_ACCEPT_LANGUAGE"].to_s.scan(/[a-z]{2}/i).find { |code| supported_locale?(code) }
  end

  def supported_locale?(code)
    code.present? && I18n.available_locales.map(&:to_s).include?(code.to_s)
  end

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

    redirect_to login_path, alert: t("flash.authentication_required")
  end

  def require_admin!
    return if current_user&.admin?

    redirect_to dashboard_path, alert: t("flash.not_authorized")
  end
end
