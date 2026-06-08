class LegalPagesController < ApplicationController
  def imprint
    show("imprint")
  end

  def privacy
    show("privacy")
  end

  def terms
    show("terms")
  end

  def ai_transparency
    show("ai_transparency")
  end

  def subprocessors
    show("subprocessors")
  end

  def security
    show("security")
  end

  private

  def show(slug)
    path = LegalPage.resolve(slug, locale: I18n.locale)
    raise ActionController::RoutingError, "Not Found" unless path

    @legal_slug = slug
    @page_title = t("legal_pages.#{slug}.title")
    @legal_content = path.read
    @legal_markdown = LegalPage.markdown?(path)
    render :show
  end
end
