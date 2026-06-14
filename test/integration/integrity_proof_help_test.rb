require "test_helper"

class IntegrityProofHelpTest < ActionDispatch::IntegrationTest
  test "renders integrity proof help in english" do
    get integrity_proof_help_path

    assert_response :success
    assert_select "[data-testid='integrity-proof-help']"
    assert_select "[data-testid='integrity-proof-summary']"
    assert_select "[data-testid='integrity-proof-claim-unchanged']", text: /not been changed since the recording was made/
    assert_select "[data-testid='integrity-proof-claim-exists-since']", text: /timestamp date/
    assert_select "[data-testid='integrity-proof-technical']", text: /integrity-certificate\.json/
    assert_select "[data-testid='integrity-proof-technical-audience']", text: /technically minded users/
    assert_select "h1", text: "Integrity proof for recordings"
  end

  test "renders integrity proof help in german" do
    patch locale_path(:de)

    get integrity_proof_help_path

    assert_response :success
    assert_select "[data-testid='integrity-proof-summary']", text: /Das beweist Nodl/
    assert_select "[data-testid='integrity-proof-claim-unchanged']", text: /seit der Aufnahme nicht verändert/
    assert_select "[data-testid='integrity-proof-claim-exists-since']", text: /Zeitstempel-Datum/
    assert_select "[data-testid='integrity-proof-technical']", text: /integrity-certificate\.json/
    assert_select "[data-testid='integrity-proof-technical-audience']", text: /technisch versierte Nutzer/
    assert_select "[data-testid='integrity-proof-technical'] pre code", text: /shasum -a 256/
    assert_select "h1", text: "Integritätsnachweis für Aufnahmen"
  end
end
