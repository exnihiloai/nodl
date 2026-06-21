module ApplicationHelper
  WORKSPACE_NAME_SUFFIX = /\s+Workspace\z/i
  # Underline is stored as inline HTML (<u>) because Markdown has no syntax for it.
  MARKDOWN_ALLOWED_TAGS = (Rails::HTML5::SafeListSanitizer.allowed_tags.to_a + %w[u]).uniq.freeze

  def workspace_display_name(workspace)
    workspace.name.to_s.sub(WORKSPACE_NAME_SUFFIX, "")
  end

  def render_markdown(content)
    return "" if content.blank?

    begin
      html = MarkdownRenderer.to_html(content)
      sanitize(html, tags: MARKDOWN_ALLOWED_TAGS)
    rescue StandardError => e
      Rails.logger.error("Markdown rendering failed: #{e.message}")
      simple_format(ERB::Util.html_escape(content))
    end
  end
end
