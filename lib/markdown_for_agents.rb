require "nokogiri"
require "reverse_markdown"

# Rack middleware that implements HTTP content negotiation for text/markdown
# (per RFC 9110 §12). When a client sends `Accept: text/markdown`, the
# middleware lets Rails render the page as HTML, then converts the <main>
# element to Markdown and returns it with Content-Type: text/markdown.
#
# This allows AI agents and crawlers to consume page content efficiently
# without parsing HTML, and satisfies the "Markdown for Agents" agent-readiness
# check without requiring a Cloudflare Pro/Business plan.
class MarkdownForAgents
  MARKDOWN_MIME = "text/markdown"
  HTML_MIME     = "text/html"

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless markdown_requested?(env)

    # Replace the Accept header so Rails picks the html responder normally.
    original_accept = env["HTTP_ACCEPT"]
    env["HTTP_ACCEPT"] = "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8"

    status, headers, body = @app.call(env)

    env["HTTP_ACCEPT"] = original_accept

    return [ status, headers, body ] unless convertible?(status, headers)

    html     = drain(body)
    markdown = html_to_markdown(html)
    tokens   = estimate_tokens(markdown)

    headers = headers.merge(
      "Content-Type"      => "text/markdown; charset=utf-8",
      "x-markdown-tokens" => tokens.to_s
    ).tap { |h| h.delete("Content-Length") }

    [ status, headers, [ markdown ] ]
  end

  private

  def markdown_requested?(env)
    env.fetch("HTTP_ACCEPT", "").include?(MARKDOWN_MIME)
  end

  def convertible?(status, headers)
    status == 200 && headers["Content-Type"].to_s.include?(HTML_MIME)
  end

  def drain(body)
    parts = []
    body.each { |chunk| parts << chunk }
    body.close if body.respond_to?(:close)
    parts.join
  end

  def html_to_markdown(html)
    doc = Nokogiri::HTML(html)
    doc.css("script, style, noscript").each(&:remove)
    # Prefer the <main> landmark; fall back to <body> so we strip nav/footer.
    content = doc.at_css("main") || doc.at_css("body") || doc
    ReverseMarkdown.convert(content.to_html, unknown_tags: :bypass, github_flavored: true)
  end

  def estimate_tokens(text)
    # Rough approximation: ~4 characters per GPT-style token.
    (text.length / 4.0).ceil
  end
end
