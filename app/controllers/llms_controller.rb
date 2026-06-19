# Serves the llms.txt / llms-full.txt files (https://llmstxt.org) so AI search
# systems and answer engines can discover a curated description of Nodl. The
# content lives in version-controlled text files at the repo root, mirroring how
# RobotsController serves robots.txt from config/.
class LlmsController < ApplicationController
  def show
    render plain: llms_file("llms.txt"), content_type: "text/plain"
  end

  def full
    render plain: llms_file("llms-full.txt"), content_type: "text/plain"
  end

  private

  def llms_file(name)
    Rails.root.join("config", name).read
  end
end
