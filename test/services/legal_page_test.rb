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

  test "resolve falls back to the authoritative German version for unknown locales" do
    path = write_legal_page("imprint", :de, "<p>DE imprint</p>")
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

  test "resolve serves the language-suffixed document for the visitor locale" do
    de = @legal_root.join("data-protection-DE.md").write("# DE") && @legal_root.join("data-protection-DE.md")
    en = @legal_root.join("data-protection-EN.md").write("# EN") && @legal_root.join("data-protection-EN.md")

    assert_equal de, LegalPage.resolve("privacy", locale: :de)
    assert_equal en, LegalPage.resolve("privacy", locale: :en)
  end

  test "resolve falls back to the authoritative German version when a translation is missing" do
    de = @legal_root.join("terms-of-service-DE.md")
    de.write("# AGB")

    assert_equal de, LegalPage.resolve("terms", locale: :en)
    assert LegalPage.exists?("terms")
  end

  test "version reads the authoritative German document regardless of current locale" do
    @legal_root.join("data-protection-DE.md").write("**Stand:** 08. Juni 2026")
    @legal_root.join("data-protection-EN.md").write("**Stand:** 01. May 2026")

    I18n.with_locale(:en) do
      assert_equal "08. Juni 2026", LegalPage.version("privacy")
    end
  end

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
