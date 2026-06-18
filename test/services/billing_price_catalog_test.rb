require "test_helper"

class BillingPriceCatalogTest < ActiveSupport::TestCase
  def with_env(overrides)
    old = {}
    overrides.each do |key, value|
      old[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    overrides.each_key do |key|
      old[key].nil? ? ENV.delete(key) : ENV[key] = old[key]
    end
  end

  test "returns launch prices by plan region and interval" do
    starter_eu = BillingPriceCatalog.price_for(plan_code: "starter", region: "eu", interval: "monthly")
    business_us_annual = BillingPriceCatalog.price_for(plan_code: "business", region: "international", interval: "annual")

    assert_equal "eur", starter_eu.currency
    assert_equal 2_900, starter_eu.amount_cents
    assert_equal "month", starter_eu.stripe_interval

    assert_equal "usd", business_us_annual.currency
    assert_equal 129_000, business_us_annual.amount_cents
    assert_equal "year", business_us_annual.stripe_interval
  end

  test "prefers interval specific Stripe Price IDs" do
    with_env(
      "STRIPE_STARTER_PRICE_ID_EUR" => "price_monthly",
      "STRIPE_STARTER_ANNUAL_PRICE_ID_EUR" => "price_annual"
    ) do
      monthly = BillingPriceCatalog.price_for(plan_code: "starter", region: "eu", interval: "monthly")
      annual = BillingPriceCatalog.price_for(plan_code: "starter", region: "eu", interval: "annual")

      assert_equal "price_monthly", monthly.stripe_price_id
      assert_equal "price_annual", annual.stripe_price_id
    end
  end
end
