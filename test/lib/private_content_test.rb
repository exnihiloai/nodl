require "test_helper"

class PrivateContentTest < ActiveSupport::TestCase
  setup do
    @root = Rails.root.join("tmp/private_content_test/#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@root)
    @original_root = PrivateContent.root
    @original_view_root = PrivateContent.view_root
    @original_locale_root = PrivateContent.locale_root
    PrivateContent.root = @root
    PrivateContent.view_root = @root.join("views")
    PrivateContent.locale_root = @root.join("locales")
  end

  teardown do
    PrivateContent.root = @original_root
    PrivateContent.view_root = @original_view_root
    PrivateContent.locale_root = @original_locale_root
    FileUtils.rm_rf(@root)
  end

  test "detects mounted marketing templates" do
    assert_not PrivateContent.marketing?
    assert_not PrivateContent.marketing_page?(:about)

    @root.join("views/pages").mkpath
    @root.join("views/pages/home.html.erb").write("<h1>Private home</h1>")
    @root.join("views/pages/about.html.erb").write("<h1>Private about</h1>")

    assert PrivateContent.marketing?
    assert PrivateContent.marketing_page?(:about)
  end

  test "reports private locale paths" do
    @root.join("locales").mkpath
    @root.join("locales/en.yml").write("en:\n  nav:\n    examples: Examples\n")
    @root.join("locales/nested/de.yml").tap do |path|
      path.dirname.mkpath
      path.write("de:\n  nav:\n    examples: Beispiele\n")
    end

    assert_equal [
      @root.join("locales/en.yml").to_s,
      @root.join("locales/nested/de.yml").to_s
    ].sort, PrivateContent.locale_paths.sort
  end
end
