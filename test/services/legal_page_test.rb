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

  private

  def write_legal_page(slug, locale, content)
    path = @legal_root.join("#{slug}.#{locale}.html.erb")
    path.write(content)
    path
  end
end
