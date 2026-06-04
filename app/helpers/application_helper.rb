module ApplicationHelper
  def render_markdown(content)
    return "" if content.blank?

    begin
      html = Kramdown::Document.new(content).to_html
      sanitize(html)
    rescue StandardError => e
      Rails.logger.error("Markdown rendering failed: #{e.message}")
      simple_format(ERB::Util.html_escape(content))
    end
  end
end
