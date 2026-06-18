class PagesController < ApplicationController
  include PricingOverview

  before_action :require_private_marketing_page!, only: %i[
    about
    for_doctors
    for_dentists
    for_overthinkers
    for_journaling
    for_interviews
    for_coaches
    try_now
  ]

  def home
    if current_user.blank?
      prepare_pricing_overview
      ActiveSupport::Notifications.instrument("nodl.landing.visited", ip: request.remote_ip, user_agent: request.user_agent)
      return
    end

    redirect_to dashboard_path
  end

  def about; end

  def integrity_proof; end

  def for_doctors; end

  def for_dentists; end

  def for_overthinkers; end

  def for_journaling; end

  def for_interviews; end

  def for_coaches; end

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

  private

  def require_private_marketing_page!
    return if PrivateContent.marketing_page?(action_name.to_sym)

    render "errors/not_found", status: :not_found
  end
end
