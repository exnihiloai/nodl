require "test_helper"

class LegalPageTest < ActiveSupport::TestCase
  setup do
    @legal_root = Rails.root.join("tmp/legal_page_test/#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@legal_root)
    LegalPage.root = @legal_root
  end

  teardown do
    LegalPage.reset_root!
    FileUtils.rm_rf(@legal_root)
  end

  test "resolve returns localized template when present" do
    path = write_legal_page("imprint", :de, "<p>DE imprint</p>")
    assert_equal path, LegalPage.resolve("imprint", locale: :de)
  end

  test "resolve falls back to default locale" do
    path = write_legal_page("imprint", I18n.default_locale, "<p>Default imprint</p>")
    assert_equal path, LegalPage.resolve("imprint", locale: :fr)
  end

  test "exists is false when no template is present" do
    assert_not LegalPage.exists?("privacy")
  end

  test "exists is true when any locale template is present" do
    write_legal_page("privacy", :en, "<p>Privacy</p>")
    assert LegalPage.exists?("privacy")
  end

  test "resolve finds markdown by aliased document basename" do
    path = @legal_root.join("data-protection.md")
    path.write("# Datenschutz")

    assert_equal path, LegalPage.resolve("privacy", locale: :en)
    assert LegalPage.exists?("privacy")
  end

  test "resolve finds markdown named after the slug" do
    path = @legal_root.join("terms.md")
    path.write("# Terms")

    assert_equal path, LegalPage.resolve("terms", locale: :en)
  end

  test "markdown? detects markdown files" do
    assert LegalPage.markdown?(@legal_root.join("terms.md"))
    assert_not LegalPage.markdown?(@legal_root.join("imprint.en.html.erb"))
  end

  test "version extracts the Stand date from a markdown document" do
    @legal_root.join("terms-of-service.md").write("# AGB\n\n**Stand:** 08. Juni 2026  \n\nText")

    assert_equal "08. Juni 2026", LegalPage.version("terms")
  end

  test "version is nil when no Stand line is present" do
    @legal_root.join("terms.md").write("# Terms\n\nNo version marker here.")

    assert_nil LegalPage.version("terms")
  end

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
