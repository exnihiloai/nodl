module DocumentExporters
  # Sends the raw Markdown source so users can keep editing it elsewhere.
  class MarkdownExporter < BaseExporter
    def render
      document.content.to_s
    end

    def content_type
      "text/markdown"
    end

    def extension
      "md"
    end
  end
end
