class RobotsController < ApplicationController
  def show
    render plain: robots_body, content_type: "text/plain"
  end

  private

  def robots_body
    content = Rails.root.join("config/robots.txt").read.strip
    content.gsub(/^Sitemap:.*$/, "").strip + "\n\nSitemap: #{sitemap_url}\n"
  end
end
