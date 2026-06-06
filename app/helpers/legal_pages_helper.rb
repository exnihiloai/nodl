module LegalPagesHelper
  def legal_page_link(slug)
    return unless LegalPage.exists?(slug)

    link_to t("footer.#{slug}"), public_send(:"#{slug}_path"), class: "link link-hover"
  end
end
