module StructuredDataHelper
  CANONICAL_BASE = "https://nodl.now".freeze

  # Renders a <script type="application/ld+json"> tag from a Ruby hash.
  # Escapes </ to prevent </script> injection inside JSON string values.
  def json_ld_tag(data)
    json = data.to_json.gsub("</", "<\\/")
    content_tag(:script, json.html_safe, type: "application/ld+json")
  end

  def organization_schema
    {
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "Nodl",
      "legalName" => "ex-nihilo GmbH",
      "url" => "#{CANONICAL_BASE}/",
      "logo" => "#{CANONICAL_BASE}/icon.png",
      "email" => "hello@nodl.now",
      "sameAs" => [ "https://github.com/exnihiloai/nodl" ],
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => "Effingergasse 18/2-3",
        "addressLocality" => "Wien",
        "postalCode" => "1160",
        "addressCountry" => "AT"
      }
    }
  end

  def website_schema
    {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "Nodl",
      "url" => "#{CANONICAL_BASE}/",
      "inLanguage" => %w[en de]
    }
  end

  def software_application_schema
    {
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => "Nodl",
      "url" => "#{CANONICAL_BASE}/",
      "applicationCategory" => "ProductivityApplication",
      "operatingSystem" => "Web",
      "description" => "AI voice note and dictation app that turns spoken thoughts into finished, structured documents. " \
                       "Record in your browser; Nodl transcribes, understands, and formats your speech into notes, " \
                       "clinical records, journal entries, and more. No app install required.",
      "offers" => {
        "@type" => "Offer",
        "name" => "Free Trial",
        "price" => "0",
        "priceCurrency" => "EUR",
        "description" => "Up to 3 recordings, up to 1 hour each. No credit card required."
      }
    }
  end

  # items: array of [name, url] pairs in breadcrumb order.
  # Example: [["Home", "https://nodl.now/"], ["Doctors", "https://nodl.now/fuer/aerzte"]]
  def breadcrumb_schema(items)
    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items.each_with_index.map do |(name, url), idx|
        { "@type" => "ListItem", "position" => idx + 1, "name" => name, "item" => url }
      end
    }
  end

  # pairs: array of { q: "question text", a: "answer text (may contain HTML)" }
  # Answer HTML is stripped so the JSON contains clean plain text.
  def faq_page_schema(pairs)
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => pairs.map do |pair|
        {
          "@type" => "Question",
          "name" => pair[:q].to_s,
          "acceptedAnswer" => {
            "@type" => "Answer",
            "text" => strip_tags(pair[:a].to_s)
          }
        }
      end
    }
  end
end
