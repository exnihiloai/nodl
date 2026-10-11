# Picks the sign-up pitch that matches what an article is about, so a reader
# who came for interview transcription is not offered a journaling app. The
# copy lives under content_pages.cta.<topic> in the locale files.
module ContentPageCtaHelper
  CTA_TOPICS = {
    "interview" => /interview|einwilligung|consent|transkri|transcri/,
    "practice" => /dokumentation|documentation|sitzung|session|therap|behandlung|clinical|coaching|notes|notizen/,
    "journal" => /tagebuch|journal|gedankenkarussell|diary/
  }.freeze

  def content_page_cta_topic(slug = params[:slug])
    CTA_TOPICS.find { |_topic, pattern| slug.to_s.match?(pattern) }&.first || "general"
  end

  def content_page_cta_text(key, slug = params[:slug])
    t("content_pages.cta.#{content_page_cta_topic(slug)}.#{key}")
  end

  def content_page_show?
    controller_name == "content_pages" && action_name == "show"
  end
end
