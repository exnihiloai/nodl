class RobotsController < ApplicationController
  def show
    render plain: robots_body, content_type: "text/plain"
  end

  private

  def robots_body
    <<~ROBOTS
      User-agent: *
      Allow: /

      Sitemap: #{sitemap_url}
    ROBOTS
  end
end
