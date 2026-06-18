class PaymentsController < ApplicationController
  include PricingOverview

  skip_forgery_protection only: :webhook

  def show
    prepare_pricing_overview(ensure_billing_catalog: true)
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
    unless stripe_secret_key.present? && params[:session_id].present?
      redirect_to checkout_error_path, alert: t("flash.payments.checkout_failed")
      return
    end

    Stripe.api_key = stripe_secret_key
    checkout_session = Stripe::Checkout::Session.retrieve(params[:session_id])
    unless completed_checkout_session?(checkout_session)
      Rails.logger.error("stripe_checkout_success_incomplete session_id=#{params[:session_id]}")
      redirect_to checkout_error_path, alert: t("flash.payments.checkout_failed")
      return
    end

    workspace = process_checkout_completed!(checkout_session)
    user = workspace&.users&.order("memberships.created_at ASC")&.first

    unless user&.active?
      Rails.logger.error("stripe_checkout_success_without_active_user session_id=#{params[:session_id]}")
      redirect_to checkout_error_path, alert: t("flash.payments.checkout_failed")
      return
    end

    sign_in_after_checkout!(user:, workspace:)
    redirect_to dashboard_path, notice: t("flash.payments.checkout_success")
  rescue Stripe::StripeError => e
    Rails.logger.error("stripe_checkout_success_failed error=#{e.message}")
    redirect_to checkout_error_path, alert: t("flash.payments.checkout_failed")
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
    workspace = Workspace.find_by(id: metadata_value(metadata, "workspace_id")) || provision_workspace_from_checkout!(session_obj)
    plan_version = BillingPlanVersion.find_by(id: metadata_value(metadata, "plan_version_id"))
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

    workspace
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
    params = {
      mode: "subscription",
      success_url:,
      cancel_url:,
      line_items: [ checkout_line_item(plan_version:, selected_price:) ],
      automatic_tax: { enabled: true },
      metadata: checkout_metadata(plan_version:, selected_price:, plan_code:, region:, interval:)
    }
    params[:client_reference_id] = current_workspace.id if current_workspace
    params[:customer_email] = current_user.email if current_user
    params
  end

  def checkout_metadata(plan_version:, selected_price:, plan_code:, region:, interval:)
    {
      user_id: current_user&.id,
      workspace_id: current_workspace&.id,
      plan_version_id: plan_version.id,
      plan_code:,
      billing_region: region,
      billing_interval: interval,
      currency: selected_price.currency,
      amount_cents: selected_price.amount_cents
    }.compact.transform_values(&:to_s)
  end

  def provision_workspace_from_checkout!(session_obj)
    email = checkout_email(session_obj)
    return if email.blank?

    normalized_email = email.to_s.strip.downcase
    return if normalized_email.blank?

    ActiveRecord::Base.transaction do
      user = User.find_or_initialize_by(email: normalized_email)
      unless user.persisted?
        password = SecureRandom.base58(32)
        user.password = password
        user.password_confirmation = password
        user.preferred_language = I18n.locale.to_s if user.respond_to?(:preferred_language=)
      end
      user.active = true if user.respond_to?(:active=) && user.active.nil?
      user.save!

      workspace = user.workspaces.order("memberships.created_at ASC").first
      unless workspace
        workspace = Workspace.create!(name: "#{normalized_email.split("@").first.titleize} Workspace")
        Membership.create!(user:, workspace:, role: :owner)
      end

      workspace
    end
  end

  def checkout_email(session_obj)
    customer_details = session_obj.respond_to?(:customer_details) ? session_obj.customer_details : nil
    details_email = if customer_details.respond_to?(:email)
      customer_details.email
    elsif customer_details.respond_to?(:[])
      customer_details[:email] || customer_details["email"]
    end
    details_email.presence || (session_obj.customer_email if session_obj.respond_to?(:customer_email))
  end

  def completed_checkout_session?(session_obj)
    status = session_obj.status if session_obj.respond_to?(:status)
    payment_status = session_obj.payment_status if session_obj.respond_to?(:payment_status)
    status == "complete" && payment_status.in?(%w[paid no_payment_required])
  end

  def metadata_value(metadata, key)
    return if metadata.blank?
    return metadata[key] if metadata.respond_to?(:[]) && metadata[key].present?

    symbol_key = key.to_sym
    metadata[symbol_key] if metadata.respond_to?(:[])
  end

  def sign_in_after_checkout!(user:, workspace:)
    reset_session
    session[:user_id] = user.id
    session[:current_workspace_id] = workspace.id
    user.update!(last_login_at: Time.current)
    ActiveSupport::Notifications.instrument("nodl.user.logged_in", user:)
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
