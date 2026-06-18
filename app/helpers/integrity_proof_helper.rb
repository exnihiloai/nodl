module IntegrityProofHelper
  def integrity_proof_back_path
    internal_referrer_path || (user_signed_in? ? dashboard_path : root_path(anchor: "pricing"))
  end

  private

  def internal_referrer_path
    return if request.referer.blank?

    referrer = URI.parse(request.referer)
    return unless referrer.host == request.host

    path = referrer.path.presence || root_path
    query = referrer.query.present? ? "?#{referrer.query}" : ""
    fragment = referrer.fragment.present? ? "##{referrer.fragment}" : ""
    "#{path}#{query}#{fragment}"
  rescue URI::InvalidURIError
    nil
  end
end
