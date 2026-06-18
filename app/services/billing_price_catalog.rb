class BillingPriceCatalog
  Plan = Data.define(
    :code,
    :name,
    :description_key,
    :highlight,
    :features,
    :prices
  )

  Price = Data.define(
    :plan_code,
    :region,
    :interval,
    :currency,
    :amount_cents,
    :stripe_price_id,
    :env_keys
  ) do
    def annual?
      interval == "annual"
    end

    def stripe_interval
      annual? ? "year" : "month"
    end
  end

  REGIONS = {
    "eu" => { label_key: "payments.show.regions.eu", currency: "eur" },
    "international" => { label_key: "payments.show.regions.international", currency: "usd" }
  }.freeze

  INTERVALS = {
    "monthly" => { label_key: "payments.show.intervals.monthly" },
    "annual" => { label_key: "payments.show.intervals.annual" }
  }.freeze

  MONTHLY_PRICES = {
    "starter" => { "eur" => 2_900, "usd" => 3_900 },
    "business" => { "eur" => 9_900, "usd" => 12_900 }
  }.freeze

  FEATURES = {
    "starter" => %w[
      payments.show.features.starter_recordings
      payments.show.features.starter_formats
      payments.show.features.unlimited_exports
      payments.show.features.monthly_usage_window
    ],
    "business" => %w[
      payments.show.features.business_recordings
      payments.show.features.unlimited_formats
      payments.show.features.integrity
      payments.show.features.monthly_usage_window
    ]
  }.freeze

  PLAN_META = {
    "starter" => {
      name: "Starter",
      description_key: "payments.show.plans.starter.description",
      highlight: false
    },
    "business" => {
      name: "Business",
      description_key: "payments.show.plans.business.description",
      highlight: true
    }
  }.freeze

  def self.plans(region:, interval:)
    new(region:, interval:).plans
  end

  def self.price_for(plan_code:, region:, interval:)
    new(region:, interval:).price_for(plan_code)
  end

  def self.normalize_region(region)
    region.to_s.presence_in(REGIONS.keys) || "eu"
  end

  def self.normalize_interval(interval)
    interval.to_s.presence_in(INTERVALS.keys) || "monthly"
  end

  def self.normalize_plan(plan_code)
    plan_code.to_s.presence_in(PLAN_META.keys) || "starter"
  end

  attr_reader :region, :interval

  def initialize(region:, interval:)
    @region = self.class.normalize_region(region)
    @interval = self.class.normalize_interval(interval)
  end

  def plans
    PLAN_META.map do |code, meta|
      Plan.new(
        code:,
        name: meta.fetch(:name),
        description_key: meta.fetch(:description_key),
        highlight: meta.fetch(:highlight),
        features: FEATURES.fetch(code),
        prices: INTERVALS.keys.index_with { |price_interval| price_for(code, interval: price_interval) }
      )
    end
  end

  def price_for(plan_code, interval: self.interval)
    normalized_plan = self.class.normalize_plan(plan_code)
    normalized_interval = self.class.normalize_interval(interval)
    currency = REGIONS.fetch(region).fetch(:currency)
    monthly_amount = MONTHLY_PRICES.fetch(normalized_plan).fetch(currency)
    amount_cents = normalized_interval == "annual" ? monthly_amount * 10 : monthly_amount
    env_keys = stripe_price_env_keys(normalized_plan, currency, normalized_interval)

    Price.new(
      plan_code: normalized_plan,
      region:,
      interval: normalized_interval,
      currency:,
      amount_cents:,
      stripe_price_id: env_keys.filter_map { |key| ENV[key].presence }.first,
      env_keys:
    )
  end

  private

  def stripe_price_env_keys(plan_code, currency, interval)
    plan = plan_code.upcase
    currency_code = currency.upcase
    interval_name = interval.upcase

    keys = [
      "STRIPE_#{plan}_#{interval_name}_PRICE_ID_#{currency_code}",
      "STRIPE_#{plan}_PRICE_ID_#{currency_code}"
    ]

    keys << "STRIPE_#{plan}_PRICE_ID" if interval == "monthly"
    keys << "STRIPE_PRICE_ID" if plan_code == "starter" && interval == "monthly"
    keys
  end
end
