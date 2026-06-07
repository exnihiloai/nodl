require "test_helper"

class LicensesTest < ActionDispatch::IntegrationTest
  test "licenses page renders successfully" do
    get licenses_path
    assert_response :success
    assert_select "h1", text: I18n.t("pages.licenses.heading")
  end

  test "licenses page lists key redistributed components and their notices" do
    get licenses_path
    assert_response :success

    # Libraries, font, icons, and CSS the application ships.
    assert_includes response.body, "rails"
    assert_includes response.body, "Inter (typeface)"
    assert_includes response.body, "Lucide (icons)"
    assert_includes response.body, "DaisyUI"

    # A reproduced copyright notice and license text must be present.
    assert_includes response.body, "Copyright"
    assert_includes response.body, "Permission is hereby granted"
  end

  test "licenses page reproduces each license family text" do
    get licenses_path
    assert_response :success

    ThirdPartyLicenses.groups.each do |group|
      assert_includes response.body, %(id="license-#{group.id}"),
        "expected a section for #{group.id}"
    end
    # Spot-check a couple of canonical texts beyond MIT.
    assert_includes response.body, "Apache License"
    assert_includes response.body, "SIL OPEN FONT LICENSE"
  end

  test "about page links to the licenses page" do
    get about_path
    assert_response :success
    assert_select "a[data-testid='about-licenses-link'][href=?]", licenses_path
  end

  test "footer links to the licenses page" do
    get root_path
    assert_response :success
    assert_includes response.body, licenses_path
    assert_includes response.body, I18n.t("footer.licenses", locale: :en)
  end

  test "every component has a name and copyright notice" do
    ThirdPartyLicenses.groups.each do |group|
      assert group.body.present?, "#{group.id} missing license body"
      group.components.each do |component|
        assert component.name.present?, "component without name in #{group.id}"
        assert component.copyright.present?,
          "#{component.name} (#{group.id}) missing copyright notice"
      end
    end
  end
end
