require "test_helper"

class TransformerProfilesIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user_with_workspace(email: "formats@example.test")
    @workspace = @user.workspaces.first
    post login_path, params: { email: @user.email, password: "Valid123" }
  end

  test "renders the new, show, and edit pages" do
    get new_transformer_profile_path
    assert_response :success
    assert_select "[data-testid=format-form]"
    assert_select "[data-testid=example-files-dropzone]"
    assert_select "[data-testid=example-text-input]"

    profile = create_custom_profile
    attach_example(profile, "guide.txt")

    get transformer_profile_path(profile)
    assert_response :success
    assert_select "[data-testid=format-name]", text: profile.name

    get edit_transformer_profile_path(profile)
    assert_response :success
    assert_select "[data-testid=example-files-list]"
  end

  test "creates a custom format with guidelines and example files" do
    assert_difference -> { @workspace.transformer_profiles.count }, 1 do
      post transformer_profiles_path, params: {
        transformer_profile: {
          name: "Meeting Notes",
          instructions: "Write structured meeting notes with decisions and action items.",
          example_files: [
            Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "example.txt"), "text/plain"),
            Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "example.pdf"), "application/pdf")
          ]
        }
      }
    end

    assert_redirected_to dashboard_path
    profile = @workspace.transformer_profiles.find_by!(handle: "meeting-notes")
    assert_equal "meeting-notes", profile.handle
    assert_equal 2, profile.example_files.count
  end

  test "stores pasted text as a plain-text example document" do
    post transformer_profiles_path, params: {
      transformer_profile: {
        name: "Pasted",
        instructions: "Follow the pasted style.",
        example_text: "Weekly Status\n\nThis is the example body."
      }
    }

    assert_redirected_to dashboard_path
    profile = @workspace.transformer_profiles.find_by!(handle: "pasted")
    assert_equal 1, profile.example_files.count

    file = profile.example_files.first
    assert_equal "text/plain", file.content_type
    assert_equal "Weekly Status.txt", file.filename.to_s
    assert_equal "Weekly Status\n\nThis is the example body.", file.download
  end

  test "names pasted text generically when it has no usable first line" do
    post transformer_profiles_path, params: {
      transformer_profile: { name: "Blank-titled", instructions: "x", example_text: "   \n\nbody text" }
    }

    profile = @workspace.transformer_profiles.find_by!(handle: "blank-titled")
    assert_equal "body text.txt", profile.example_files.first.filename.to_s
  end

  test "blank pasted text adds no example" do
    post transformer_profiles_path, params: {
      transformer_profile: { name: "No paste", instructions: "x", example_text: "   \n  " }
    }

    profile = @workspace.transformer_profiles.find_by!(handle: "no-paste")
    assert_equal 0, profile.example_files.count
  end

  test "pasted text counts toward the three-example limit" do
    post transformer_profiles_path, params: {
      transformer_profile: {
        name: "Too many",
        instructions: "x",
        example_text: "A pasted example.",
        example_files: %w[example.txt example.md example.pdf].map do |name|
          Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", name))
        end
      }
    }

    assert_response :unprocessable_entity
    assert_nil @workspace.transformer_profiles.find_by(handle: "too-many")
  end

  test "rejects a custom format without guidelines" do
    assert_no_difference -> { @workspace.transformer_profiles.count } do
      post transformer_profiles_path, params: {
        transformer_profile: { name: "Empty", instructions: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "derives a unique handle when names collide" do
    @workspace.transformer_profiles.create!(name: "Notes", handle: "notes", instructions: "x")

    post transformer_profiles_path, params: {
      transformer_profile: { name: "Notes", instructions: "Second one." }
    }

    profile = @workspace.transformer_profiles.find_by!(handle: "notes-2")
    assert_equal "Notes", profile.name
  end

  test "updating appends example files instead of replacing them" do
    profile = create_custom_profile
    attach_example(profile, "first.txt")

    patch transformer_profile_path(profile), params: {
      transformer_profile: {
        name: profile.name,
        instructions: profile.instructions,
        example_files: [ Rack::Test::UploadedFile.new(Rails.root.join("test", "fixtures", "files", "example.md"), "text/markdown") ]
      }
    }

    assert_redirected_to dashboard_path
    assert_equal 2, profile.reload.example_files.count
  end

  test "removes a single example file" do
    profile = create_custom_profile
    attach_example(profile, "removable.txt")
    attachment = profile.example_files.attachments.first

    assert_difference -> { profile.reload.example_files.count }, -1 do
      delete example_file_transformer_profile_path(profile, attachment)
    end
  end

  test "deletes a custom format" do
    profile = create_custom_profile

    assert_difference -> { @workspace.transformer_profiles.count }, -1 do
      delete transformer_profile_path(profile)
    end
    assert_redirected_to dashboard_path
  end

  test "cannot manage a format from another workspace" do
    other = create_user_with_workspace(email: "other@example.test").workspaces.first
    foreign = other.transformer_profiles.create!(name: "Foreign", handle: "foreign", instructions: "x")

    get edit_transformer_profile_path(foreign)

    assert_response :not_found
  end

  test "shows the default format with its stored guidelines and example content" do
    default = @workspace.transformer_profiles.find_by!(handle: "default")

    get transformer_profile_path(default)

    assert_response :success
    assert_select "[data-testid=format-name]", text: default.name
    assert_select "[data-testid=format-instructions]", text: /well-structured Markdown/
    # The example's content, not just its filename, is shown.
    assert_select "[data-testid=format-examples]", text: /Example Document/
  end

  test "edit form for the default is prefilled with its stored guidelines" do
    default = @workspace.transformer_profiles.find_by!(handle: "default")

    get edit_transformer_profile_path(default)

    assert_response :success
    assert_select "[data-testid=format-instructions-input]", text: /well-structured Markdown/
  end

  test "edit form keeps its fields and save button inside one form" do
    # Regression: rendering the example-files list with button_to nested a
    # <form> inside the edit form. Browsers close the outer form at that point,
    # orphaning the name/guidelines fields and the Save button, so nothing
    # submitted and no change was saved. Parse the body the way a browser does
    # (HTML5) and assert every field still lives inside the edit form.
    default = @workspace.transformer_profiles.find_by!(handle: "default")

    get edit_transformer_profile_path(default)
    assert_response :success

    form = Nokogiri::HTML5(response.body).at_css("form[data-testid=format-form]")
    assert form, "edit form not found"
    assert form.at_css("[data-testid=format-name-input]"), "name field is outside the form"
    assert form.at_css("[data-testid=format-instructions-input]"), "guidelines field is outside the form"
    assert form.at_css("[data-testid=format-submit-button]"), "save button is outside the form"
    # The remove control must be a Turbo link, not a nested <form>.
    assert_select "a[data-testid=remove-example-file-button][data-turbo-method=delete]"
  end

  test "renaming an existing format saves and confirms" do
    profile = create_custom_profile
    attach_example(profile, "guide.txt")

    patch transformer_profile_path(profile), params: {
      transformer_profile: { name: "Renamed Journal", instructions: profile.instructions }
    }

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_select ".alert-success", text: /updated/
    assert_equal "Renamed Journal", profile.reload.name
  end

  test "editing the default updates its guidelines and keeps it the default" do
    default = @workspace.transformer_profiles.find_by!(handle: "default")

    patch transformer_profile_path(default), params: {
      transformer_profile: { name: "Basic Summary", instructions: "My own house style." }
    }

    assert_redirected_to dashboard_path
    default.reload
    assert_equal "My own house style.", default.instructions
    assert default.default?
  end

  test "the default format cannot be deleted" do
    default = @workspace.transformer_profiles.find_by!(handle: "default")

    assert_no_difference -> { @workspace.transformer_profiles.count } do
      delete transformer_profile_path(default)
    end
    assert_redirected_to dashboard_path
    assert_equal "The default format can't be deleted.", flash[:alert]
  end

  test "rejects creating a format when workspace reached format limit" do
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Exercise trial format limit"
    )

    2.times do |index|
      @workspace.transformer_profiles.create!(
        name: "Format #{index}",
        handle: "format-#{index}",
        instructions: "Guidelines #{index}."
      )
    end

    assert_no_difference -> { @workspace.transformer_profiles.count } do
      post transformer_profiles_path, params: {
        transformer_profile: { name: "Too many", instructions: "No room left." }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "maximum of 2 formats"
  end

  test "redirects new format page when workspace reached format limit" do
    WorkspaceEntitlementGrant.grant!(
      workspace: @workspace,
      plan_code: "trial",
      source: "trial",
      status: "trialing",
      trial: true,
      reason: "Exercise trial format limit"
    )

    2.times do |index|
      @workspace.transformer_profiles.create!(
        name: "Format #{index}",
        handle: "format-#{index}",
        instructions: "Guidelines #{index}."
      )
    end

    get new_transformer_profile_path

    assert_redirected_to dashboard_path
    assert_equal "Limit of 2 formats reached", flash[:alert]
  end

  private

  def create_custom_profile
    @workspace.transformer_profiles.create!(
      name: "Journal",
      handle: "journal",
      instructions: "Reflective entries."
    )
  end

  def attach_example(profile, filename)
    profile.example_files.attach(
      io: StringIO.new("content"),
      filename: filename,
      content_type: "text/plain"
    )
  end
end
