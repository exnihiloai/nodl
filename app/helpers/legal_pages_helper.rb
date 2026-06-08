module LegalPagesHelper
  # Table markup is dropped by the default sanitizer allowlist, but legal
  # documents (privacy policy, AI transparency) rely on tables. Legal content is
  # operator-authored from private/legal/, so we extend the trusted allowlist
  # with table elements rather than rendering the raw HTML unsanitized.
  TABLE_TAGS = %w[table caption colgroup col thead tbody tfoot tr td th].freeze
  TABLE_ATTRIBUTES = %w[colspan rowspan scope].freeze

  LEGAL_ALLOWED_TAGS = (Rails::HTML5::SafeListSanitizer.allowed_tags.to_a + TABLE_TAGS).uniq.freeze
  LEGAL_ALLOWED_ATTRIBUTES = (Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a + TABLE_ATTRIBUTES).uniq.freeze

  def legal_page_link(slug)
    return unless LegalPage.exists?(slug)

    link_to t("footer.#{slug}"), public_send(:"#{slug}_path"), class: "link link-hover"
  end

  # Slugs of the documents contextually related to the given legal page that are
  # actually published, in their configured order.
  def legal_related_slugs(current_slug)
    LegalPage::RELATED.fetch(current_slug.to_s, []).select { |slug| LegalPage.exists?(slug) }
  end

  def render_legal_markdown(content)
    return "" if content.blank?

    html = Kramdown::Document.new(content).to_html
    sanitize(html, tags: LEGAL_ALLOWED_TAGS, attributes: LEGAL_ALLOWED_ATTRIBUTES)
  rescue StandardError => e
    Rails.logger.error("Legal markdown rendering failed: #{e.message}")
    simple_format(ERB::Util.html_escape(content))
  end
end
