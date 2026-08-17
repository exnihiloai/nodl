# Emits <link rel="canonical"> and hreflang alternate tags for public pages.
# Vertical marketing pages exist once per language under different URLs
# (/fuer/* renders German, /for/* renders English), so each variant declares
# itself canonical and points to its sibling via hreflang. Single-URL pages
# (home, about, try-now) get a plain self-canonical to guard against
# query-string duplicates.
module SeoHelper
  LOCALIZED_PAGE_PAIRS = {
    for_doctors: { de: :for_doctors_path, en: :for_doctors_en_path },
    for_dentists: { de: :for_dentists_path, en: :for_dentists_en_path },
    for_overthinkers: { de: :for_overthinkers_path, en: :for_overthinkers_en_path },
    for_journaling: { de: :for_journaling_path, en: :for_journaling_en_path },
    for_interviews: { de: :for_interviews_path, en: :for_interviews_en_path },
    for_coaches: { de: :for_coaches_path, en: :for_coaches_en_path }
  }.freeze

  SINGLE_URL_ACTIONS = {
    home: :root_path,
    about: :about_path,
    try_now: :try_now_path
  }.freeze

  CONTENT_INDEX_PAIR = { de: :artikel_index_path, en: :article_index_path }.freeze

  # Articles that exist in both languages under different slugs. Each twin gets a
  # self-canonical plus hreflang pointing at its sibling, so the pair is treated as
  # language variants rather than competing pages. Articles absent from this map
  # (single-language ones) keep a plain self-canonical.
  CONTENT_PAGE_PAIRS = {
    "interview-transkribieren" => "how-to-transcribe-an-interview",
    "interview-transkription-datenschutz" => "interview-transcription-gdpr",
    "einwilligungserklaerung-interview" => "interview-consent-form",
    "interview-anonymisieren" => "anonymising-interview-transcripts",
    "interview-transkribieren-lassen-kosten" => "interview-transcription-cost",
    "behandlungsdokumentation-diktieren" => "clinical-documentation-dictation",
    "psychotherapie-dokumentation" => "therapy-session-notes",
    "physiotherapie-dokumentation" => "physiotherapy-documentation"
  }.freeze

  CONTENT_PAGE_PAIRS_BY_EN = CONTENT_PAGE_PAIRS.invert.freeze

  # Path to the same article in the other language, or nil when this article has
  # no twin (or only one half is deployed). Used by the article hub to offer a
  # language switch per entry.
  def content_page_twin_path(locale, slug)
    pair = content_page_pair(locale.to_s, slug)
    return unless pair

    locale.to_s == "de" ? article_path(pair.fetch(:en)) : artikel_path(pair.fetch(:de))
  end

  def seo_link_tags
    return unless controller_name.in?(%w[pages content_pages])

    if controller_name == "pages" && (pair = LOCALIZED_PAGE_PAIRS[action_name.to_sym])
      localized_page_link_tags(pair)
    elsif controller_name == "pages" && (path_helper = SINGLE_URL_ACTIONS[action_name.to_sym])
      tag.link(rel: "canonical", href: canonical_url(public_send(path_helper)))
    elsif controller_name == "content_pages" && action_name == "index"
      localized_page_link_tags(CONTENT_INDEX_PAIR)
    elsif controller_name == "content_pages" && action_name == "show"
      content_page_canonical_tag
    end
  end

  private

  def localized_page_link_tags(pair)
    de_url = canonical_url(public_send(pair.fetch(:de)))
    en_url = canonical_url(public_send(pair.fetch(:en)))

    safe_join([
      tag.link(rel: "canonical", href: I18n.locale == :de ? de_url : en_url),
      tag.link(rel: "alternate", hreflang: "de", href: de_url),
      tag.link(rel: "alternate", hreflang: "en", href: en_url),
      tag.link(rel: "alternate", hreflang: "x-default", href: en_url)
    ], "\n")
  end

  def content_page_canonical_tag
    locale = request.path_parameters[:locale].to_s
    slug = params[:slug]
    return unless PrivateContent.content_page?(locale, slug)

    path = locale == "de" ? artikel_path(slug) : article_path(slug)
    canonical = tag.link(rel: "canonical", href: canonical_url(path))

    pair = content_page_pair(locale, slug)
    return canonical unless pair

    de_url = canonical_url(artikel_path(pair.fetch(:de)))
    en_url = canonical_url(article_path(pair.fetch(:en)))

    safe_join([
      canonical,
      tag.link(rel: "alternate", hreflang: "de", href: de_url),
      tag.link(rel: "alternate", hreflang: "en", href: en_url),
      tag.link(rel: "alternate", hreflang: "x-default", href: en_url)
    ], "\n")
  end

  # Resolves the sibling slug for a translated article, but only when both
  # templates actually exist — a half-deployed pair must not advertise a 404.
  def content_page_pair(locale, slug)
    de_slug, en_slug =
      if locale == "de"
        [ slug, CONTENT_PAGE_PAIRS[slug] ]
      else
        [ CONTENT_PAGE_PAIRS_BY_EN[slug], slug ]
      end
    return unless de_slug && en_slug
    return unless PrivateContent.content_page?("de", de_slug) && PrivateContent.content_page?("en", en_slug)

    { de: de_slug, en: en_slug }
  end

  def canonical_url(path)
    "#{StructuredDataHelper::CANONICAL_BASE}#{path}"
  end
end
