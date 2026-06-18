module PagesHelper
  ProductFeature = Data.define(:icon, :tone, :title, :description)

  # Icon + tone stay in code; the user-facing title/description come from i18n
  # (pages.product_features.items.<key>).
  PRODUCT_FEATURE_DEFS = [
    { key: "languages", icon: "languages", tone: "text-primary" },
    { key: "translation", icon: "globe", tone: "text-info" },
    { key: "transcript", icon: "activity", tone: "text-accent" },
    { key: "templates", icon: "wand-sparkles", tone: "text-primary" },
    { key: "speakers", icon: "users", tone: "text-info" },
    { key: "audio_download", icon: "download", tone: "text-warning" },
    { key: "formats", icon: "file-text", tone: "text-success" },
    { key: "export", icon: "copy", tone: "text-accent" },
    { key: "devices", icon: "mic", tone: "text-primary" }
  ].freeze

  def product_features
    PRODUCT_FEATURE_DEFS.map do |feature|
      ProductFeature.new(
        icon: feature[:icon],
        tone: feature[:tone],
        title: t("pages.product_features.items.#{feature[:key]}.title"),
        description: t("pages.product_features.items.#{feature[:key]}.description")
      )
    end
  end

  # Gratis-Test limits shown in the pricing card's framed "included" box.
  def free_plan_limits
    [
      t("pages.plans.limits.recordings", count: trial_limit_for("recordings")),
      t("pages.plans.limits.formats", count: trial_limit_for("custom_formats")),
      t("pages.plans.limits.duration", count: PlanLimits::MAX_RECORDING_DURATION.in_hours.to_i)
    ]
  end

  def free_plan_capability_features
    t("pages.plans.capabilities")
  end

  # Full Gratis-Test baseline — higher tiers reference this with
  # "Everything in the free trial, plus:" plus pro_plan_features (or similar).
  def free_plan_features
    free_plan_limits + free_plan_capability_features
  end

  def pro_plan_features
    t("pages.plans.pro")
  end

  private

  def trial_limit_for(capability)
    BillingCatalog::LIMITS.fetch("trial").fetch(capability).fetch("limit")
  end
end
