module DocumentExporters
  # Renders the document's Markdown (as HTML) into a PDF using prawn-html, a
  # pure-Ruby renderer with no native/system dependencies.
  class PdfExporter < BaseExporter
    def render
      pdf = Prawn::Document.new(page_size: "A4", margin: 56)
      PrawnHtml.append_html(pdf, document_html)
      pdf.render
    end

    def content_type
      "application/pdf"
    end

    def extension
      "pdf"
    end
  end
end
