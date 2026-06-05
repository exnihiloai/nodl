module DocumentExporters
  # Converts the document's Markdown (as HTML) into a real .docx file via
  # htmltoword, which builds OOXML from HTML. Headings, paragraphs, bold/italic,
  # and lists carry over so the file opens cleanly in MS Word / LibreOffice.
  class DocxExporter < BaseExporter
    def render
      Htmltoword::Document.create(document_html)
    end

    def content_type
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    end

    def extension
      "docx"
    end
  end
end
