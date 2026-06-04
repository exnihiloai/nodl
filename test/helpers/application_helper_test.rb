require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "render_markdown converts markdown to safe HTML" do
    markdown = "# Hello World\n\nThis is a [link](http://example.com) and **bold** text."
    result = render_markdown(markdown)

    assert_match "<h1>Hello World</h1>", result
    assert_match "This is a <a href=\"http://example.com\">link</a>", result
    assert_match "<strong>bold</strong>", result
  end

  test "render_markdown sanitizes unsafe HTML tags" do
    markdown = "# Header\n\n<script>alert('XSS')</script>\n\n[untrusted](javascript:alert('XSS'))"
    result = render_markdown(markdown)

    refute_match "<script>", result
    refute_match "javascript:alert", result
  end

  test "render_markdown handles empty or blank content gracefully" do
    assert_equal "", render_markdown(nil)
    assert_equal "", render_markdown("   ")
  end

  test "render_markdown falls back gracefully to simple_format when parsing fails" do
    Kramdown::Document.any_instance.stubs(:to_html).raises(StandardError.new("Parsing error"))

    markdown = "Broken **text** & <script>alert(1)</script>"
    result = render_markdown(markdown)

    # Should be safely escaped and formatted with simple_format
    assert_match "Broken **text** &amp; &lt;script&gt;alert(1)&lt;/script&gt;", result
  end
end
