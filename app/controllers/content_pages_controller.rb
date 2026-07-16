# Serves operator-authored content pages (articles, guides) from the private
# companion repo. Each page is a plain ERB template at
# private/views/content/<locale>/<slug>.html.erb; the route fixes the locale so
# every article has exactly one language and one URL. Deployments without
# private content simply 404 here, mirroring the marketing page contract.
class ContentPagesController < ApplicationController
  def index
    @pages = PrivateContent.content_pages(locale_from_route)

    render "errors/not_found", status: :not_found if @pages.empty?
  end

  def show
    unless PrivateContent.content_page?(locale_from_route, params[:slug])
      return render "errors/not_found", status: :not_found
    end

    render "content/#{locale_from_route}/#{params[:slug]}"
  end
end
