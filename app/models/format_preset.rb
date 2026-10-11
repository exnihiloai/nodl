# Ready-made starting points for a custom format, so a new user does not face a
# blank instructions field. A preset only pre-fills the "new format" form; the
# saved format is an ordinary custom format and counts against the plan limit.
# Names and instructions live under format_presets.<key> in the locale files.
class FormatPreset
  KEYS = %w[session_note interview_summary journal_entry].freeze

  attr_reader :key

  def self.all
    KEYS.map { |key| new(key) }
  end

  def self.find(key)
    new(key.to_s) if KEYS.include?(key.to_s)
  end

  def initialize(key)
    @key = key
  end

  def name
    I18n.t("format_presets.#{key}.name")
  end

  def instructions
    I18n.t("format_presets.#{key}.instructions")
  end

  def attributes
    { name:, instructions: }
  end
end
