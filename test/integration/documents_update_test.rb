require "test_helper"

class DocumentsUpdateTest < ActionDispatch::IntegrationTest
  def create_document(workspace:, title: "Field Notes", content: "# Notes\n\nbody\n")
    user = workspace.memberships.first.user
    session = workspace.recording_sessions.new(creator: user, title: title, transformer_handle: "default")
    attach_sample_audio(session)
    session.save!
    workspace.documents.create!(
      recording_session: session,
      title: title,
      content: content,
      transformer_handle: "default",
      generated_at: Time.current
    )
  end

  def login(user)
    post login_path, params: { email: user.email, password: "Valid123" }
  end

  test "update requires authentication" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first)

    patch document_path(document), params: { document: { content: "# Updated\n" } }

    assert_redirected_to login_path
  end

  test "updates document content and redirects with notice" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first, content: "# Original\n\nbody\n")
    login(user)

    patch document_path(document), params: { document: { content: "# Corrected\n\nfixed text\n" } }

    assert_redirected_to document_path(document)
    follow_redirect!
    assert_select ".alert-success", text: /saved/i
    assert_equal "# Corrected\n\nfixed text\n", document.reload.content
    assert_select ".prose", text: /Corrected/
    assert_select ".prose", text: /fixed text/
  end

  test "edited content is used for markdown download" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first, content: "# Original\n")
    login(user)

    patch document_path(document), params: { document: { content: "# Updated export\n" } }

    get download_document_path(document, format: "md")

    assert_equal "# Updated export\n", response.body
  end

  test "rejects blank content" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first)
    login(user)

    patch document_path(document), params: { document: { content: "   " } }

    assert_response :unprocessable_entity
    assert_select "[data-testid='document-content-input']"
    assert_not_equal "", document.reload.content
  end

  test "cannot update a document from another workspace" do
    owner = create_user_with_workspace
    document = create_document(workspace: owner.workspaces.first)

    intruder = create_user_with_workspace
    login(intruder)

    patch document_path(document), params: { document: { content: "# Intrusion\n" } }

    assert_response :not_found
    assert_equal "# Notes\n\nbody\n", document.reload.content
  end

  test "show page includes edit controls" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first, content: "# Visible\n\ncontent\n")
    login(user)

    get document_path(document)

    assert_response :success
    assert_select "[data-testid='edit-document']", text: /Edit/i
    assert_select "[data-testid='document-content-input']"
    assert_select "[data-testid='document-content-editor']"
    assert_select "[data-document-editor-command-param='link']"
    assert_select "[data-document-editor-target='blockTypeLabel']"
    assert_select "[data-testid='document-block-type-h2']"
    assert_select "[data-testid='document-block-type-blockquote']"
    assert_select "[data-testid='document-insert-menu']", text: /Insert/i
    assert_select "[data-testid='document-insert-hr']"
    assert_select "[data-document-editor-command-param='undo']"
  end
end
