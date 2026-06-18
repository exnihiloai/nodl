class PaymentsController < ApplicationController
  before_action :authenticate_user!, only: %i[checkout success cancel]
  skip_forgery_protection only: :webhook

  def show
    BillingCatalog.ensure!
    @stripe_configured = stripe_secret_key.present?
    @selected_region = BillingPriceCatalog.normalize_region(params[:region])
    @selected_interval = params[:interval].present? ? BillingPriceCatalog.normalize_interval(params[:interval]) : "annual"
    @plan_cards = BillingPriceCatalog.plans(region: @selected_region, interval: @selected_interval)
  end

  def checkout
    BillingCatalog.ensure!
    unless stripe_secret_key.present?
      redirect_to checkout_error_path, alert: t("flash.payments.not_configured")
      return
    end

    plan_code = BillingPriceCatalog.normalize_plan(params[:plan])
    region = BillingPriceCatalog.normalize_region(params[:region])
    interval = BillingPriceCatalog.normalize_interval(params[:interval])
    plan_version = BillingCatalog.active_version!(plan_code)
    selected_price = BillingPriceCatalog.price_for(plan_code:, region:, interval:)

    Stripe.api_key = stripe_secret_key

    success_url = payments_success_url(session_id: "{CHECKOUT_SESSION_ID}")
    cancel_url = payments_url(region:, interval:)

    checkout_session = Stripe::Checkout::Session.create(
      checkout_session_params(
        plan_version:,
        selected_price:,
        success_url:,
        cancel_url:,
        plan_code:,
        region:,
        interval:
      )
    )

    session_url = checkout_session.respond_to?(:url) ? checkout_session.url : nil
    if session_url.blank?
      Rails.logger.error("stripe_checkout_missing_session_url")
      redirect_to checkout_error_path, alert: t("flash.payments.checkout_failed")
      return
    end

    redirect_to session_url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    Rails.logger.error("stripe_checkout_failed error=#{e.message}")
    redirect_to checkout_error_path, alert: t("flash.payments.checkout_failed")
  end

  def success
    @session_id = params[:session_id]
    @product_name = ENV.fetch("STRIPE_PRODUCT_NAME", "Nodl Starter Plan")
  end

  def cancel
    unless checkout_error_page?
      redirect_to payments_path
    end
  end

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
      entitlement.usage_period_started_at ||= Time.current
      entitlement.usage_period_ends_at ||= 1.month.from_now
      entitlement.save!
    end
  end

  def checkout_line_item(plan_version:, selected_price:)
    if selected_price.stripe_price_id.present?
      { price: selected_price.stripe_price_id, quantity: 1 }
    else
      {
        price_data: {
          currency: selected_price.currency,
          unit_amount: selected_price.amount_cents,
          recurring: { interval: selected_price.stripe_interval },
          product_data: { name: plan_version.billing_plan.display_name }
        },
        quantity: 1
      }
    end
  end

  def checkout_session_params(plan_version:, selected_price:, success_url:, cancel_url:, plan_code:, region:, interval:)
    {
      mode: "subscription",
      success_url:,
      cancel_url:,
      line_items: [ checkout_line_item(plan_version:, selected_price:) ],
      automatic_tax: { enabled: true },
      client_reference_id: current_workspace&.id,
      customer_email: current_user.email,
      metadata: checkout_metadata(plan_version:, selected_price:, plan_code:, region:, interval:)
    }
  end

  def checkout_metadata(plan_version:, selected_price:, plan_code:, region:, interval:)
    {
      user_id: current_user.id,
      workspace_id: current_workspace&.id,
      plan_version_id: plan_version.id,
      plan_code:,
      billing_region: region,
      billing_interval: interval,
      currency: selected_price.currency,
      amount_cents: selected_price.amount_cents
    }
  end

  def stripe_secret_key
    ENV["STRIPE_SECRET_KEY"]
  end

  def checkout_error_path
    payments_cancel_path(reason: "checkout_failed")
  end

  def checkout_error_page?
    params[:reason] == "checkout_failed" || flash[:alert].present?
  end
end
