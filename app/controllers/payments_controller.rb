class PaymentsController < ApplicationController
  before_action :authenticate_user!, only: %i[checkout success cancel]
  skip_forgery_protection only: :webhook

  def show
    BillingCatalog.ensure!
    @stripe_configured = stripe_secret_key.present?
    @product_name = ENV.fetch("STRIPE_PRODUCT_NAME", "Nodl Starter Plan")
    @amount_cents = ENV.fetch("STRIPE_DEFAULT_AMOUNT", "1900").to_i
    @currency = ENV.fetch("STRIPE_CURRENCY", "usd").upcase
    @stripe_price_id = ENV["STRIPE_PRICE_ID"]
    @paid_plan_versions = BillingPlanVersion.active.includes(:billing_plan).select(&:paid?)
  end

  def checkout
    BillingCatalog.ensure!
    unless stripe_secret_key.present?
      redirect_to payments_path, alert: t("flash.payments.not_configured")
      return
    end

    plan_code = params[:plan].presence || "starter"
    plan_version = BillingPlan.find_by!(code: plan_code).billing_plan_versions.active.order(active_from: :desc, created_at: :desc).first
    unless plan_version&.stripe_price_id.present?
      redirect_to payments_path, alert: t("flash.payments.plan_unavailable")
      return
    end

    Stripe.api_key = stripe_secret_key

    success_url = payments_success_url(session_id: "{CHECKOUT_SESSION_ID}")
    cancel_url = payments_cancel_url

    checkout_session = Stripe::Checkout::Session.create(
      mode: "subscription",
      success_url:,
      cancel_url:,
      line_items: [ { price: plan_version.stripe_price_id, quantity: 1 } ],
      automatic_tax: { enabled: true },
      metadata: {
        user_id: current_user&.id,
        workspace_id: current_workspace&.id,
        plan_version_id: plan_version.id
      }
    )

    session_url = checkout_session.respond_to?(:url) ? checkout_session.url : nil
    if session_url.blank?
      Rails.logger.error("stripe_checkout_missing_session_url")
      redirect_to payments_path, alert: t("flash.payments.checkout_failed")
      return
    end

    redirect_to session_url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    Rails.logger.error("stripe_checkout_failed error=#{e.message}")
    redirect_to payments_path, alert: t("flash.payments.checkout_failed")
  end

  def success
    @session_id = params[:session_id]
    @product_name = ENV.fetch("STRIPE_PRODUCT_NAME", "Nodl Starter Plan")
  end

  def cancel; end

  def webhook
    secret = ENV["STRIPE_WEBHOOK_SECRET"]

    if secret.blank?
      render json: { error: "Stripe webhook secret not configured." }, status: :service_unavailable
      return
    end

    payload = request.raw_post
    signature = request.env["HTTP_STRIPE_SIGNATURE"]
    if signature.blank?
      render json: { error: "Missing Stripe signature header." }, status: :bad_request
      return
    end

    event = Stripe::Webhook.construct_event(payload, signature, secret)
    Rails.logger.info("stripe_webhook_event type=#{event.type} id=#{event.id}")

    ActiveRecord::Base.transaction do
      StripeWebhookEvent.create!(
        stripe_event_id: event.id,
        event_type: event.type,
        processed_at: Time.current
      )

      if event.type == "checkout.session.completed"
        session_obj = event.data.object
        process_checkout_completed!(session_obj)
      end
    end

    render json: { received: true }
  rescue ActiveRecord::RecordNotUnique
    render json: { received: true }
  rescue ActiveRecord::RecordInvalid => e
    raise unless e.record.is_a?(StripeWebhookEvent)

    render json: { received: true }
  rescue JSON::ParserError, Stripe::SignatureVerificationError => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def process_checkout_completed!(session_obj)
    metadata = session_obj.respond_to?(:metadata) ? session_obj.metadata : {}
    workspace = Workspace.find_by(id: metadata&.fetch("workspace_id", nil))
    plan_version = BillingPlanVersion.find_by(id: metadata&.fetch("plan_version_id", nil))
    return unless workspace && plan_version

    WorkspaceEntitlement.find_or_initialize_by(workspace:).tap do |entitlement|
      entitlement.billing_plan_version = plan_version
      entitlement.source = "stripe"
      entitlement.status = "active"
      entitlement.limits_snapshot = plan_version.limits.deep_dup
      entitlement.stripe_customer_id = session_obj.customer if session_obj.respond_to?(:customer)
      entitlement.stripe_subscription_id = session_obj.subscription if session_obj.respond_to?(:subscription)
      entitlement.current_period_started_at ||= Time.current
      entitlement.current_period_ends_at ||= 1.month.from_now
      entitlement.save!
    end
  end

  def stripe_secret_key
    ENV["STRIPE_SECRET_KEY"]
  end
end
