module ApplicationHelper
  WORKSPACE_NAME_SUFFIX = /\s+Workspace\z/i

  def workspace_display_name(workspace)
    workspace.name.to_s.sub(WORKSPACE_NAME_SUFFIX, "")
  end

  def render_markdown(content)
    return "" if content.blank?

    begin
      html = MarkdownRenderer.to_html(content)
      sanitize(html)
    rescue StandardError => e
      Rails.logger.error("Markdown rendering failed: #{e.message}")
      simple_format(ERB::Util.html_escape(content))
    end
  end
end
