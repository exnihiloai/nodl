require "test_helper"

class LegalPagesTest < ActionDispatch::IntegrationTest
  setup do
    @legal_root = Rails.root.join("tmp/legal_pages_test/#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@legal_root)
    LegalPage.root = @legal_root
  end

  teardown do
    LegalPage.reset_root!
    FileUtils.rm_rf(@legal_root)
  end

  test "legal page returns not found when private template is missing" do
    assert_not LegalPage.exists?("terms")

    get terms_path
    assert_response :not_found
  end

  test "legal page renders private template when present" do
    write_legal_page("privacy", :en, "<section><h1>Test Privacy</h1><p>Operator legal copy.</p></section>")

    get privacy_path
    assert_response :success
    assert_includes response.body, "Test Privacy"
    assert_includes response.body, "Operator legal copy."
  end

  test "footer omits legal links when private templates are missing" do
    get root_path
    assert_response :success
    assert_not_includes response.body, terms_path
    assert_not_includes response.body, privacy_path
    assert_not_includes response.body, imprint_path
  end

  test "footer shows legal link when private template exists" do
    write_legal_page("terms", :en, "<section><h1>Test Terms</h1></section>")

    get root_path
    assert_response :success
    assert_includes response.body, terms_path
    assert_includes response.body, I18n.t("footer.terms", locale: :en)
  end

  test "legal page uses german template when locale is german" do
    write_legal_page("privacy", :de, "<section><h1>Test Datenschutz</h1></section>")
    write_legal_page("privacy", :en, "<section><h1>Test Privacy</h1></section>")

    patch locale_path(locale: :de)
    follow_redirect!

    get privacy_path
    assert_response :success
    assert_includes response.body, "Test Datenschutz"
    assert_not_includes response.body, "Test Privacy"
  end

  test "legal page renders markdown content as html" do
    @legal_root.join("data-protection.md").write("# Datenschutz\n\nWir schützen **deine** Daten.")

    get privacy_path
    assert_response :success
    assert_includes response.body, "<h1"
    assert_includes response.body, "Datenschutz"
    assert_includes response.body, "<strong>deine</strong>"
  end

  test "ai transparency page renders from markdown" do
    @legal_root.join("ai-transparency.md").write("# AI Transparency\n\nNodl nutzt KI.")

    get ai_transparency_path
    assert_response :success
    assert_includes response.body, "AI Transparency"
  end

  test "privacy page links to ai transparency in related documents" do
    @legal_root.join("data-protection.md").write("# Datenschutz")
    @legal_root.join("ai-transparency.md").write("# AI Transparency")

    get privacy_path
    assert_response :success
    assert_includes response.body, ai_transparency_path
    assert_includes response.body, I18n.t("footer.ai_transparency", locale: :en)
  end

  test "subprocessors page renders from markdown" do
    @legal_root.join("subprocessors-EN.md").write("# Subprocessor Register\n\n| Name | Status |\n|---|---|\n| Hetzner | Active |")

    get subprocessors_path
    assert_response :success
    assert_includes response.body, "Subprocessor Register"
    assert_includes response.body, "Hetzner"
  end

  test "privacy page links to subprocessors in related documents" do
    @legal_root.join("data-protection.md").write("# Datenschutz")
    @legal_root.join("subprocessors-EN.md").write("# Subprocessor Register")

    get privacy_path
    assert_response :success
    assert_includes response.body, subprocessors_path
    assert_includes response.body, I18n.t("footer.subprocessors", locale: :en)
  end

  test "security page renders from markdown" do
    @legal_root.join("security-EN.md").write("# Security Measures\n\nTLS and workspace isolation.")

    get security_path
    assert_response :success
    assert_includes response.body, "Security Measures"
    assert_includes response.body, "workspace isolation"
  end

  test "privacy page links to security in related documents" do
    @legal_root.join("data-protection.md").write("# Datenschutz")
    @legal_root.join("security-EN.md").write("# Security Measures")

    get privacy_path
    assert_response :success
    assert_includes response.body, security_path
    assert_includes response.body, I18n.t("footer.security", locale: :en)
  end

  test "footer omits detailed compliance pages, keeping only core legal links" do
    @legal_root.join("terms-of-service.md").write("# Terms")
    @legal_root.join("ai-transparency.md").write("# AI Transparency")
    @legal_root.join("subprocessors-EN.md").write("# Subprocessors")
    @legal_root.join("security-EN.md").write("# Security")

    get root_path
    assert_response :success
    assert_select "footer a[href=?]", terms_path
    # Marketing content may link compliance pages in context (trust sections);
    # the footer itself stays limited to the core legal links.
    assert_select "footer a[href=?]", ai_transparency_path, count: 0
    assert_select "footer a[href=?]", subprocessors_path, count: 0
    assert_select "footer a[href=?]", security_path, count: 0
  end

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
