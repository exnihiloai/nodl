require "test_helper"
require "json"

# Verifies that public marketing pages emit correct, parseable JSON-LD structured
# data. All assertions operate on the OSS helper logic (StructuredDataHelper) and
# the public page routes — no private/authenticated paths are tested here.
class StructuredDataTest < ActionDispatch::IntegrationTest
  # ── homepage ──────────────────────────────────────────────────────────────────

  test "homepage includes parseable JSON-LD script tags" do
    get root_path
    schemas = extract_schemas(response.body)
    assert schemas.any?, "expected at least one application/ld+json block on the homepage"
  end

  test "homepage has Organization schema with required fields" do
    get root_path
    org = find_schema(response.body, "Organization")
    assert_not_nil org, "Organization schema missing"
    assert_equal "Nodl", org["name"]
    assert_equal "ex-nihilo GmbH", org["legalName"]
    assert org["url"].start_with?("https://nodl.now"), "url must be canonical"
    assert org["logo"].start_with?("https://nodl.now"), "logo must be canonical"
    assert_equal "hello@nodl.now", org["email"]
    assert_includes Array(org["sameAs"]), "https://github.com/exnihiloai/nodl", "sameAs must include OSS GitHub repo"
    assert_nil org["aggregateRating"], "must not emit fake aggregateRating"
    assert_nil org["review"], "must not emit fake reviews"
  end

  test "homepage has WebSite schema" do
    get root_path
    site = find_schema(response.body, "WebSite")
    assert_not_nil site, "WebSite schema missing"
    assert_equal "Nodl", site["name"]
    assert site["url"].start_with?("https://nodl.now")
  end

  test "homepage has SoftwareApplication schema" do
    get root_path
    app = find_schema(response.body, "SoftwareApplication")
    assert_not_nil app, "SoftwareApplication schema missing"
    assert_equal "Nodl", app["name"]
    assert_equal "ProductivityApplication", app["applicationCategory"]
    assert_equal "Web", app["operatingSystem"]
    assert_nil app["aggregateRating"], "must not emit fake aggregateRating"
  end

  test "homepage has FAQPage schema matching visible FAQ" do
    get root_path
    faq = find_schema(response.body, "FAQPage")
    assert_not_nil faq, "FAQPage schema missing on homepage"
    questions = faq["mainEntity"]
    assert_equal 6, questions.length, "homepage has 6 visible FAQ questions"
    questions.each do |q|
      assert_equal "Question", q["@type"]
      assert q["name"].present?, "FAQ question must have a name"
      assert_equal "Answer", q.dig("acceptedAnswer", "@type")
      assert q.dig("acceptedAnswer", "text").present?, "FAQ answer must not be blank"
      assert_no_match(/<[^>]+>/, q.dig("acceptedAnswer", "text"), "answer text must not contain HTML tags")
    end
  end

  test "homepage JSON-LD navigational fields use canonical https://nodl.now URLs" do
    get root_path
    schemas = extract_schemas(response.body)
    navigational_keys = %w[url logo item image]
    schemas.each do |schema|
      check_urls_in(schema, navigational_keys)
    end
  end

  # ── subpages — BreadcrumbList ──────────────────────────────────────────────

  test "about page has BreadcrumbList with two items" do
    Dir.mktmpdir do |private_views|
      with_private_view_root(private_views) do
        views = Pathname.new(private_views)
        views.join("pages").mkpath
        # about page lives in private/; use the real private views bound in test env
      end
    end

    # The about page is only rendered when the private view exists; skip if not.
    get about_path
    skip "private views not available in this test env" unless response.successful?

    crumb = find_schema(response.body, "BreadcrumbList")
    assert_not_nil crumb, "BreadcrumbList missing on /about"
    items = crumb["itemListElement"]
    assert_equal 2, items.length
    assert_equal 1, items[0]["position"]
    assert_equal "https://nodl.now/", items[0]["item"]
    assert_equal 2, items[1]["position"]
    assert items[1]["item"].include?("nodl.now"), "second breadcrumb must use canonical URL"
  end

  test "a vertical page has BreadcrumbList and FAQPage" do
    get for_doctors_path
    skip "private views not available in this test env" unless response.successful?

    assert_not_nil find_schema(response.body, "BreadcrumbList"), "BreadcrumbList missing on doctors page"
    assert_not_nil find_schema(response.body, "FAQPage"), "FAQPage missing on doctors page"
  end

  # ── no schema on auth/app pages ────────────────────────────────────────────

  test "login page does not emit Organization or SoftwareApplication schema" do
    get login_path
    assert_nil find_schema(response.body, "Organization")
    assert_nil find_schema(response.body, "SoftwareApplication")
  end

  # ── helper unit-style ──────────────────────────────────────────────────────

  test "json_ld_tag escapes closing script tags in JSON values" do
    helper = ApplicationController.helpers
    data = { "name" => "test</script><script>alert(1)" }
    output = helper.json_ld_tag(data)
    assert_not_includes output, "</script><script>", "must escape </ in JSON values"
  end

  test "faq_page_schema strips HTML from answers" do
    helper = ApplicationController.helpers
    pairs = [ { q: "Question?", a: "<strong>Bold answer</strong>" } ]
    schema = helper.faq_page_schema(pairs)
    text = schema.dig("mainEntity", 0, "acceptedAnswer", "text")
    assert_equal "Bold answer", text
  end

  private

  def extract_schemas(html)
    html.scan(%r{<script[^>]+type="application/ld\+json"[^>]*>(.*?)</script>}m)
        .map { |m| JSON.parse(m.first) rescue nil }
        .compact
  end

  def find_schema(html, type)
    extract_schemas(html).find { |s| s["@type"] == type }
  end

  def check_urls_in(obj, keys)
    case obj
    when Hash
      obj.each do |k, v|
        if keys.include?(k) && v.is_a?(String) && v.start_with?("http")
          assert v.start_with?("https://nodl.now"), "non-canonical URL in field '#{k}': #{v}"
        else
          check_urls_in(v, keys)
        end
      end
    when Array
      obj.each { |item| check_urls_in(item, keys) }
    end
  end
end
