module DocumentExporters
  # Shared behaviour for the format-specific exporters. Subclasses provide the
  # binary payload (#render), the MIME type, and the file extension.
  class BaseExporter
    include ActionView::Helpers::SanitizeHelper

    def initialize(document)
      @document = document
    end

    # Bytes to send to the browser.
    def render
      raise NotImplementedError
    end

    def content_type
      raise NotImplementedError
    end

    def extension
      raise NotImplementedError
    end

    def filename
      slug = @document.title.parameterize.presence || "document"
      "#{slug}.#{extension}"
    end

    private

    attr_reader :document

    # Renders the document's Markdown to a standalone HTML string used by the
    # PDF and Word exporters. The title is included as a top-level heading so it
    # appears in the exported file.
    def document_html
      body = MarkdownRenderer.to_html(document.content)
      heading = ERB::Util.html_escape(document.title)
      "<h1>#{heading}</h1>\n#{body}"
    end
  end
end
