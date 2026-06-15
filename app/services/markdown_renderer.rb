# Renders Markdown stored on documents to HTML. Kramdown's default parser does
# not understand GFM strikethrough (~~text~~), which the WYSIWYG editor writes
# via Turndown — normalize that syntax before parsing so view and export match
# the editor.
class MarkdownRenderer
  GFM_STRIKETHROUGH = /~~(?=\S)(.+?)(?<=\S)~~/m

  def self.to_html(content)
    return "" if content.blank?

    normalized = content.to_s.gsub(GFM_STRIKETHROUGH) { "<del>#{$1}</del>" }
    Kramdown::Document.new(normalized).to_html
  end
end
