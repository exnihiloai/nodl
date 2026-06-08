require "test_helper"

class LegalConsentTest < ActiveSupport::TestCase
  setup do
    @user = create_user_with_workspace
    @legal_root = Rails.root.join("tmp/legal_consent_test/#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@legal_root)
    LegalPage.root = @legal_root
  end

  teardown do
    LegalPage.reset_root!
    FileUtils.rm_rf(@legal_root)
  end

  test "requires a known document, version, and accepted_at" do
    consent = LegalConsent.new(user: @user)
    assert_not consent.valid?
    assert consent.errors.of_kind?(:document, :blank)
    assert consent.errors.of_kind?(:version, :blank)
    assert consent.errors.of_kind?(:accepted_at, :blank)

    consent.document = "marketing"
    consent.valid?
    assert consent.errors.of_kind?(:document, :inclusion)
  end

  test "record_for stores a row per published consentable document" do
    @legal_root.join("terms-of-service.md").write("**Stand:** 08. Juni 2026")
    @legal_root.join("data-protection.md").write("**Stand:** 07. Juni 2026")

    assert_difference "LegalConsent.count", 2 do
      LegalConsent.record_for(@user)
    end

    assert_equal "08. Juni 2026", @user.legal_consents.find_by(document: "terms").version
    assert_equal "07. Juni 2026", @user.legal_consents.find_by(document: "privacy").version
  end

  test "record_for skips documents that are not published" do
    @legal_root.join("terms-of-service.md").write("**Stand:** 08. Juni 2026")

    assert_difference "LegalConsent.count", 1 do
      LegalConsent.record_for(@user)
    end

    assert_equal %w[terms], @user.legal_consents.map(&:document)
  end

  test "a later document version produces an additional consent row" do
    @legal_root.join("terms-of-service.md").write("**Stand:** 08. Juni 2026")
    LegalConsent.record_for(@user)

    @legal_root.join("terms-of-service.md").write("**Stand:** 01. Juli 2026")
    assert_difference "LegalConsent.count", 1 do
      LegalConsent.record_for(@user)
    end

    versions = @user.legal_consents.where(document: "terms").order(:id).pluck(:version)
    assert_equal [ "08. Juni 2026", "01. Juli 2026" ], versions
  end
end
