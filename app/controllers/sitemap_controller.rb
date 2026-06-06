class SitemapController < ApplicationController
  def show
    @entries = Sitemap.entries(base_url: request.base_url, url_helpers: self)

    respond_to do |format|
      format.xml
    end
  end
end
