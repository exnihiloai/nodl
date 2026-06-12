require "test_helper"

# Enforces the project's typography convention mechanically: the middot (·,
# U+00B7) and the em dash (—, U+2014) must not appear in user-facing view
# templates or translation locale files. Both glyphs slipped into the marketing
# pages and locale copy before; this guard moves the catch from "someone notices
# in review" to the gate, and the failure message names the fix.
#
# This is intentionally NOT an absolute ban. A genuinely justified use (e.g. a
# string compared against an em-dash sentinel produced elsewhere) can opt out by
# placing a directive on the offending line or the line directly above it:
#
#   ERB:   <%# typography:allow: <why this glyph is correct here> %>
#   YAML:  # typography:allow: <why this glyph is correct here>
#
# The justification after `typography:allow:` must be substantive (>= 15
# characters), so opting out forces a real reason rather than a silent bypass.
class TypographyGlyphTest < ActiveSupport::TestCase
  MIDDOT = "·".freeze   # ·
  EM_DASH = "—".freeze  # —
  FORBIDDEN = { MIDDOT => "middot (·, U+00B7)", EM_DASH => "em dash (—, U+2014)" }.freeze

  # `typography:allow:` followed by at least 15 non-trailing-whitespace chars of
  # justification. A bare directive with no real reason does not count.
  ALLOW_DIRECTIVE = /typography:allow:\s*(\S.{14,})/

  GLOBS = [ "app/views/**/*.erb", "config/locales/**/*.yml" ].freeze

  test "no middot or em dash in view templates and locale files" do
    offenses = []

    GLOBS.flat_map { |glob| Rails.root.glob(glob) }.sort.each do |path|
      lines = path.read(encoding: "UTF-8").lines
      lines.each_with_index do |line, index|
        FORBIDDEN.each do |glyph, label|
          next unless line.include?(glyph)
          next if exempt?(lines, index)

          rel = path.relative_path_from(Rails.root)
          offenses << "#{rel}:#{index + 1} contains #{label}"
        end
      end
    end

    assert_empty offenses, <<~MSG
      Forbidden typography found in view templates / locale files:

        #{offenses.join("\n  ")}

      Why this is flagged: the middot (·) and the em dash (—) are not part of the
      project's typographic style for UI copy or translations. They read as
      machine-generated, vary across fonts, and were cleaned out of the landing
      pages deliberately. Keep prose to plain punctuation.

      How to fix each occurrence:
        • Em dash (—): replace with the punctuation the sentence actually needs.
          - comma for an aside:           "schnell, und dann ..."
          - colon to introduce a list:    "drei Schritte: a, b, c"
          - period for two statements:    "Kein Schlafversprechen. Das wäre unseriös."
        • Middot (·): drop it. Use a comma between metadata bits, or restructure
          so no separator glyph is needed.
        • Need a range dash ("9–17 Uhr")? Use an en dash (–, U+2013) sparingly.
          The en dash is allowed and is not flagged by this check.

      If a glyph is genuinely correct here (e.g. matching a sentinel value), opt
      out by adding a directive on the same line or the line directly above it,
      with a real reason (>= 15 characters):
        ERB:   <%# typography:allow: matches the em-dash placeholder from X %>
        YAML:  # typography:allow: matches the em-dash placeholder from X
    MSG
  end

  private

  # Exempt if a justified `typography:allow:` directive sits on the offending
  # line or the line immediately above it.
  def exempt?(lines, index)
    candidates = [ lines[index] ]
    candidates << lines[index - 1] if index.positive?
    candidates.compact.any? { |line| line.match?(ALLOW_DIRECTIVE) }
  end
end
