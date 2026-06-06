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

  private

  def show(slug)
    path = LegalPage.resolve(slug, locale: I18n.locale)
    raise ActionController::RoutingError, "Not Found" unless path

    @page_title = t("legal_pages.#{slug}.title")
    @legal_content = path.read
    render :show
  end
end
