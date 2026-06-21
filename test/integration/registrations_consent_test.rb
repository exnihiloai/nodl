require "test_helper"

class RegistrationsConsentTest < ActionDispatch::IntegrationTest
  setup do
    @legal_root = Rails.root.join("tmp/registrations_consent_test/#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@legal_root)
    LegalPage.root = @legal_root
  end

  teardown do
    LegalPage.reset_root!
    FileUtils.rm_rf(@legal_root)
  end

  test "registration form shows the consent checkbox and document links when published" do
    publish_legal_docs

    get register_path
    assert_response :success
    assert_includes response.body, "accept_legal"
    assert_includes response.body, terms_path
    assert_includes response.body, privacy_path
  end

  test "registration is rejected without consent" do
    publish_legal_docs

    assert_no_difference "User.count" do
      post register_path, params: registration_params(accept: false)
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("registrations.errors.legal_not_accepted")
  end

  test "registration records dated consent for terms and privacy" do
    publish_legal_docs

    assert_difference "LegalConsent.count", 2 do
      post register_path, params: registration_params(accept: true)
    end
    assert_redirected_to dashboard_path

    consents = User.find_by(email: "consent@example.com").legal_consents.order(:document)
    assert_equal %w[privacy terms], consents.map(&:document)
    assert_equal "07. Juni 2026", consents.find { |c| c.document == "privacy" }.version
    assert_equal "08. Juni 2026", consents.find { |c| c.document == "terms" }.version
    assert(consents.all? { |c| c.accepted_at.present? })
  end

  test "registration succeeds without a checkbox when no legal docs are published" do
    # @legal_root is empty, so consent is not required.
    assert_difference "User.count", 1 do
      assert_no_difference "LegalConsent.count" do
        post register_path, params: registration_params(accept: false)
      end
    end

    assert_redirected_to dashboard_path
  end

  test "registration stores the active language preference" do
    patch locale_path(locale: "de")

    assert_difference "User.count", 1 do
      post register_path, params: registration_params(accept: false)
    end

    user = User.find_by!(email: "consent@example.com")
    assert_equal "de", user.preferred_language
  end

  private

  def publish_legal_docs
    @legal_root.join("terms-of-service.md").write("# AGB\n\n**Stand:** 08. Juni 2026  \n\nText")
    @legal_root.join("data-protection.md").write("# Datenschutz\n\n**Stand:** 07. Juni 2026  \n\nText")
  end

  def registration_params(accept:)
    {
      email: "consent@example.com",
      email_confirm: "consent@example.com",
      password: "ValidPass123",
      password_confirm: "ValidPass123",
      accept_legal: accept ? "1" : "0"
    }
  end
end
