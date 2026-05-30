require "application_system_test_case"

class AdminUserManagementTest < ApplicationSystemTestCase
  test "non admin is redirected away from admin users" do
    email = unique_email("member")
    create_user_with_workspace(email: email, password: "Valid123", role: :user)

    login_via_ui(email: email, password: "Valid123")
    visit admin_users_path

    assert_current_path dashboard_path, ignore_query: true
    assert_text "You are not authorized for this section."
  end

  test "admin can create a user from admin UI" do
    admin_email = unique_email("admin")
    create_user_with_workspace(email: admin_email, password: "Valid123", role: :admin)

    login_via_ui(email: admin_email, password: "Valid123")

    visit admin_users_path
    assert_text "User roster"

    click_link "Create User"

    new_email = unique_email("created")
    fill_in "Email", with: new_email
    select "User", from: "Role"
    fill_in "Password", with: "Created123"
    click_button "Create User"

    assert_current_path(%r{^/admin/users/\d+$})
    assert_text "User created successfully."
    assert_text "User Detail: #{new_email}"
  end

  test "admin can update user account lifecycle and limits" do
    admin_email = unique_email("admin")
    target_email = unique_email("target")

    create_user_with_workspace(email: admin_email, password: "Valid123", role: :admin)
    target_user = create_user_with_workspace(email: target_email, password: "Valid123", role: :user)

    login_via_ui(email: admin_email, password: "Valid123")
    visit admin_user_path(target_user)

    within("#email_section") do
      find("input[type='email']").set("updated-#{target_email}")
      click_button "Update Email"
    end
    assert_text "Email updated."
    assert_text "User Detail: updated-#{target_email}"

    within("#role_section") do
      find("select").find("option", text: "Admin").select_option
      click_button "Update Role"
    end
    assert_text "Role updated."

    within("#password_section") do
      find("input[type='password']").set("Updated123")
      click_button "Set Password"
    end
    assert_text "Password updated."

    click_button "Deactivate User"
    assert_text "User deactivated."
    assert_button "Reactivate User"

    click_button "Reactivate User"
    assert_text "User reactivated."
    assert_button "Deactivate User"

    within("#usage_section") do
      fill_in "Scans Limit", with: "250"
      fill_in "Storage (MB) Limit", with: "128"
      click_button "Update Limits"
    end
    assert_text "Usage limits updated."
    assert_text "250"
    assert_text "128"

    assert_text "Update email"
    assert_text "Update role"
    assert_text "Update usage limits"
  end
end
