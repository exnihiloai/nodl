require "test_helper"

# Guards the i18n contract: English is the source of truth and every other
# supported locale must define exactly the same set of application keys, with
# matching interpolation placeholders. Framework-provided keys (number/date/etc.)
# are excluded because their German equivalents are maintained by hand in a
# dedicated block rather than mirrored from en.
class LocaleParityTest < ActiveSupport::TestCase
  FRAMEWORK_ROOTS = %w[number date time datetime errors support activerecord helpers].freeze
  SOURCE = :en

  def flatten(hash, prefix = "")
    hash.each_with_object({}) do |(key, value), acc|
      full = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      value.is_a?(Hash) ? acc.merge!(flatten(value, full)) : acc[full] = value
    end
  end

  def app_keys(locale)
    translations = I18n.backend.send(:translations)[locale] || {}
    flatten(translations).reject { |key, _| FRAMEWORK_ROOTS.include?(key.split(".").first) }
  end

  def placeholders(value)
    value.to_s.scan(/%\{(\w+)\}/).flatten.sort
  end

  setup { I18n.backend.load_translations }

  test "german defines every application key present in english" do
    en = app_keys(:en)
    de = app_keys(:de)

    missing = en.keys - de.keys
    assert_empty missing, "German is missing keys: #{missing.sort.join(', ')}"
  end

  test "german does not define extra application keys absent from english" do
    en = app_keys(:en)
    de = app_keys(:de)

    extra = de.keys - en.keys
    assert_empty extra, "German has keys not in English: #{extra.sort.join(', ')}"
  end

  test "interpolation placeholders match between english and german" do
    en = app_keys(:en)
    de = app_keys(:de)

    mismatches = en.filter_map do |key, value|
      next unless de.key?(key)
      next if placeholders(value) == placeholders(de[key])

      "#{key}: en=#{placeholders(value)} de=#{placeholders(de[key])}"
    end

    assert_empty mismatches, "Placeholder mismatch:\n#{mismatches.join("\n")}"
  end

  test "only english and german are configured" do
    assert_equal %i[en de].sort, I18n.available_locales.sort
    assert_equal :en, I18n.default_locale
  end
end
