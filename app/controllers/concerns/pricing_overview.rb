module PricingOverview
  extend ActiveSupport::Concern

  private

  def prepare_pricing_overview(default_interval: "monthly", ensure_billing_catalog: false)
    BillingCatalog.ensure! if ensure_billing_catalog
    @stripe_configured = ENV["STRIPE_SECRET_KEY"].present?
    @selected_region = BillingPriceCatalog.normalize_region(params[:region])
    @selected_interval = params[:interval].present? ? BillingPriceCatalog.normalize_interval(params[:interval]) : default_interval
    @plan_cards = BillingPriceCatalog.plans(region: @selected_region, interval: @selected_interval)
  end
end
