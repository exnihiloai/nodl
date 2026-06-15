require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  test "renders GFM strikethrough as del elements" do
    html = MarkdownRenderer.to_html("# ~~Waldemar~~ Antons Weg\n")

    assert_includes html, "<del>Waldemar</del>"
    refute_includes html, "~~"
  end

  test "still renders standard markdown" do
    html = MarkdownRenderer.to_html("**bold** and *italic*")

    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<em>italic</em>"
  end
end
