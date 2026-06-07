class PagesController < ApplicationController
  def home
    if current_user.blank?
      ActiveSupport::Notifications.instrument("nodl.landing.visited", ip: request.remote_ip, user_agent: request.user_agent)
      return
    end

    redirect_to dashboard_path
  end

  def about; end

  def try_now; end

  def healthz
    render json: { status: "ok" }
  end

  def readyz
    status = ActiveRecord::Base.connection.active? ? "ok" : "error"

    respond_to do |format|
      format.json { render json: { status: status } }
      format.html { render partial: "shared/status_check", locals: { status: status } }
    end
  rescue StandardError
    respond_to do |format|
      format.json { render json: { status: "error" }, status: :service_unavailable }
      format.html { render partial: "shared/status_check", locals: { status: "error" }, status: :service_unavailable }
    end
  end
end
