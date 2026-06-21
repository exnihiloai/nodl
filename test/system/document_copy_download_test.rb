require "application_js_system_test_case"

class DocumentCopyDownloadTest < ApplicationJsSystemTestCase
  test "copy button copies the document and shows feedback" do
    document = create_document_for_ui

    visit document_path(document)

    assert_selector "[data-testid='copy-document']", text: "Copy"
    find("[data-testid='copy-document']").click

    assert_selector "[data-testid='copy-document']", text: "Copied"
  end

  test "download menu links to every export format" do
    document = create_document_for_ui

    visit document_path(document)

    # Links live inside a DaisyUI dropdown that is hidden until focused.
    assert_link "PDF", href: download_document_path(document, format: "pdf"), visible: :all
    assert_link "Word (.docx)", href: download_document_path(document, format: "docx"), visible: :all
    assert_link "Markdown", href: download_document_path(document, format: "md"), visible: :all
  end

  test "user can edit document text and see the updated content" do
    document = create_document_for_ui

    visit document_path(document)

    assert_selector "[data-testid='edit-document']", text: "Edit"
    find("[data-testid='edit-document']").click

    assert_selector "[data-testid='document-content-editor']", visible: :visible
    page.execute_script(<<~JS)
      const surface = document.querySelector("[data-testid='document-content-editor']");
      surface.innerHTML = "<h1>Revised title</h1><p>Corrected paragraph.</p>";
    JS
    find("[data-testid='save-document']").click

    assert_selector ".alert-success", text: "Document saved"
    assert_text "Revised title"
    assert_text "Corrected paragraph."
    assert_no_selector "[data-testid='document-content-editor']", visible: :visible
  end

  test "saving underline then bold stores bold outside underline" do
    document = create_document_for_ui

    visit document_path(document)
    find("[data-testid='edit-document']").click

    page.execute_script(<<~JS)
      const surface = document.querySelector("[data-testid='document-content-editor']");
      surface.innerHTML = "<p>Der Name der <u><strong>Person</strong></u> lautet Franz.</p>";
    JS
    find("[data-testid='save-document']").click

    assert_selector ".alert-success", text: "Document saved"
    assert_selector "strong u", text: "Person"
    assert_no_text "**Person**"
    assert_equal "Der Name der **<u>Person</u>** lautet Franz.", document.reload.content
  end

  private

  def create_document_for_ui
    email = unique_email
    user = create_user_with_workspace(email: email, password: "Valid123")
    workspace = user.workspaces.first
    session = workspace.recording_sessions.new(
      creator: user,
      title: "Field Notes",
      transformer_handle: "default"
    )
    attach_sample_audio(session)
    session.save!
    document = workspace.documents.create!(
      recording_session: session,
      title: "Field Notes",
      content: "# Heading\n\nSome **bold** text.\n",
      transformer_handle: "default",
      generated_at: Time.current
    )

    login_via_ui(email: email, password: "Valid123")
    # Wait for the authenticated session to settle (Turbo form submit is async
    # under Selenium) before navigating on.
    assert_selector "[data-testid='account-menu']"
    document
  end
end
