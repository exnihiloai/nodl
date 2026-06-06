class PaymentsController < ApplicationController
  before_action :authenticate_user!, only: %i[checkout success cancel]
  skip_forgery_protection only: :webhook

  def show
    @stripe_configured = stripe_secret_key.present?
    @product_name = ENV.fetch("STRIPE_PRODUCT_NAME", "Nodl Starter Plan")
    @amount_cents = ENV.fetch("STRIPE_DEFAULT_AMOUNT", "1900").to_i
    @currency = ENV.fetch("STRIPE_CURRENCY", "usd").upcase
    @stripe_price_id = ENV["STRIPE_PRICE_ID"]
  end

  def checkout
    unless stripe_secret_key.present?
      redirect_to payments_path, alert: t("flash.payments.not_configured")
      return
    end

    Stripe.api_key = stripe_secret_key

    success_url = payments_success_url(session_id: "{CHECKOUT_SESSION_ID}")
    cancel_url = payments_cancel_url

    line_item = if ENV["STRIPE_PRICE_ID"].present?
      { price: ENV.fetch("STRIPE_PRICE_ID"), quantity: 1 }
    else
      {
        price_data: {
          currency: ENV.fetch("STRIPE_CURRENCY", "usd"),
          product_data: { name: ENV.fetch("STRIPE_PRODUCT_NAME", "Nodl Starter Plan") },
          unit_amount: ENV.fetch("STRIPE_DEFAULT_AMOUNT", "1900").to_i
        },
        quantity: 1
      }
    end

    checkout_session = Stripe::Checkout::Session.create(
      mode: "payment",
      success_url:,
      cancel_url:,
      line_items: [ line_item ],
      automatic_tax: { enabled: true },
      metadata: {
        user_id: current_user&.id,
        workspace_id: current_workspace&.id
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

    if event.type == "checkout.session.completed"
      session_obj = event.data.object
      Rails.logger.info("stripe_checkout_completed session_id=#{session_obj.id}")
    end

    render json: { received: true }
  rescue JSON::ParserError, Stripe::SignatureVerificationError => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def stripe_secret_key
    ENV["STRIPE_SECRET_KEY"]
  end
end
