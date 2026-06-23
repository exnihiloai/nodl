require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  test "renders GFM strikethrough as del elements" do
    html = MarkdownRenderer.to_html("# ~~Waldemar~~ Antons Weg\n")

    assert_includes html, "<del>Waldemar</del>"
    refute_includes html, "~~"
  end

  test "passes inline underline HTML through" do
    html = MarkdownRenderer.to_html("**bold** and <u>underlined</u> text\n")

    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<u>underlined</u>"
  end

  test "preserves underline combined with strikethrough and emphasis" do
    html = MarkdownRenderer.to_html("~~<u>both</u>~~ and *<u>mixed</u>*\n")

    assert_includes html, "<del><u>both</u></del>"
    assert_includes html, "<em><u>mixed</u></em>"
  end

  test "repairs legacy underline wrapping markdown bold markers" do
    html = MarkdownRenderer.to_html("Der Name der <u>**Person**</u> lautet Franz.\n")

    assert_includes html, "<strong><u>Person</u></strong>"
    refute_includes html, "**"
  end

  test "still renders standard markdown" do
    html = MarkdownRenderer.to_html("**bold** and *italic*")

    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<em>italic</em>"
  end
end
