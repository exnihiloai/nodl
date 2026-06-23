# Renders Markdown stored on documents to HTML. Kramdown's default parser does
# not understand GFM strikethrough (~~text~~), which the WYSIWYG editor writes
# via Turndown — normalize that syntax before parsing so view and export match
# the editor. Underline is persisted as inline HTML (<u>…</u>) and passes
# through Kramdown unchanged.
class MarkdownRenderer
  GFM_STRIKETHROUGH = /~~(?=\S)(.+?)(?<=\S)~~/m
  # Legacy editor output stored markdown markers inside <u> (e.g. <u>**x**</u>).
  UNDERLINE_NESTING_FIXES = [
    [ %r{<u>\*\*(.+?)\*\*</u>}m, '**<u>\1</u>**' ],
    [ %r{<u>~~(.+?)~~</u>}m, '~~<u>\1</u>~~' ],
    [ %r{<u>\*(.+?)\*</u>}m, '*<u>\1</u>*' ]
  ].freeze

  def self.to_html(content)
    return "" if content.blank?

    normalized = normalize_underline_nesting(content.to_s)
    normalized = normalized.gsub(GFM_STRIKETHROUGH) { "<del>#{$1}</del>" }
    Kramdown::Document.new(normalized).to_html
  end

  def self.normalize_underline_nesting(content)
    UNDERLINE_NESTING_FIXES.reduce(content) { |text, (pattern, replacement)| text.gsub(pattern, replacement) }
  end
  private_class_method :normalize_underline_nesting
end
