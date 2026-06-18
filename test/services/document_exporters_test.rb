require "test_helper"

class DocumentExportersTest < ActiveSupport::TestCase
  def build_document(title: "Quarterly Review", content: "# Heading\n\nSome **bold** text.\n")
    workspace = Workspace.create!(name: "Exporter Workspace")
    user = User.create!(email: unique_email, password: "Valid123", password_confirmation: "Valid123")
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

  test "markdown exporter returns raw markdown" do
    document = build_document(content: "# Raw\n\ncontent\n")
    exporter = DocumentExporters.for("md", document)

    assert_equal "text/markdown", exporter.content_type
    assert_equal "quarterly-review.md", exporter.filename
    assert_equal "# Raw\n\ncontent\n", exporter.render
  end

  test "pdf exporter produces a PDF payload" do
    exporter = DocumentExporters.for("pdf", build_document)

    assert_equal "application/pdf", exporter.content_type
    assert_equal "quarterly-review.pdf", exporter.filename
    assert exporter.render.start_with?("%PDF"), "expected PDF magic bytes"
  end

  test "docx exporter produces a Word payload" do
    exporter = DocumentExporters.for("docx", build_document)

    assert_equal "application/vnd.openxmlformats-officedocument.wordprocessingml.document", exporter.content_type
    assert_equal "quarterly-review.docx", exporter.filename
    assert exporter.render.start_with?("PK"), "expected docx (zip) magic bytes"
  end

  test "filename falls back when title has no slug characters" do
    exporter = DocumentExporters.for("md", build_document(title: "!!!"))

    assert_equal "document.md", exporter.filename
  end

  test "unsupported format raises" do
    assert_raises(DocumentExporters::UnsupportedFormatError) do
      DocumentExporters.for("txt", build_document)
    end
  end
end
