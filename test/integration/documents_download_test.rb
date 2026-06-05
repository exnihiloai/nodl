require "test_helper"

class DocumentsDownloadTest < ActionDispatch::IntegrationTest
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

  test "download requires authentication" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first)

    get download_document_path(document, format: "md")

    assert_redirected_to login_path
  end

  test "downloads markdown source as an attachment" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first, content: "# Hi\n\nthere\n")
    login(user)

    get download_document_path(document, format: "md")

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match(/attachment; filename="field-notes\.md"/, response.headers["Content-Disposition"])
    assert_equal "# Hi\n\nthere\n", response.body
  end

  test "downloads a PDF" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first)
    login(user)

    get download_document_path(document, format: "pdf")

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF"), "expected PDF magic bytes"
  end

  test "downloads a Word document" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first)
    login(user)

    get download_document_path(document, format: "docx")

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.wordprocessingml.document", response.media_type
    assert response.body.start_with?("PK"), "expected docx (zip) magic bytes"
  end

  test "rejects an unsupported format" do
    user = create_user_with_workspace
    document = create_document(workspace: user.workspaces.first)
    login(user)

    get download_document_path(document, format: "txt")

    assert_response :bad_request
  end

  test "cannot download a document from another workspace" do
    owner = create_user_with_workspace
    document = create_document(workspace: owner.workspaces.first)

    intruder = create_user_with_workspace
    login(intruder)

    get download_document_path(document, format: "md")

    assert_response :not_found
  end
end
