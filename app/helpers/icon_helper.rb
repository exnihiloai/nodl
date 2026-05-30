module IconHelper
  def icon(name, label: nil, **attrs)
    path = Rails.root.join("app/assets/icons/#{name}.svg")
    return "" unless File.exist?(path)

    svg = File.read(path)
    return "" unless svg.lstrip.start_with?("<svg")

    attributes = {}
    attributes["class"] = attrs.delete(:class) if attrs[:class].present?
    attributes["role"] = "img" if label.present?
    attributes["aria-label"] = label if label.present?
    attributes["aria-hidden"] = "true" unless label.present?

    attrs.each { |key, value| attributes[key.to_s.tr("_", "-")] = value }

    attribute_string = attributes
      .compact
      .map { |key, value| %(#{key}="#{ERB::Util.html_escape(value)}") }
      .join(" ")

    svg.sub("<svg", "<svg #{attribute_string}").html_safe
  end
end
