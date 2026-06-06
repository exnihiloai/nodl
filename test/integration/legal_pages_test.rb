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

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
