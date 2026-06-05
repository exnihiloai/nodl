# Document export entry point. Maps a requested format to the matching
# exporter and exposes the shared list of supported formats so the controller
# and views stay in sync.
module DocumentExporters
  # Ordered so the download menu can iterate it directly.
  FORMATS = %w[pdf docx md].freeze

  class UnsupportedFormatError < StandardError; end

  def self.for(format, document)
    case format.to_s
    when "pdf"  then PdfExporter.new(document)
    when "docx" then DocxExporter.new(document)
    when "md"   then MarkdownExporter.new(document)
    else
      raise UnsupportedFormatError, "Unsupported export format: #{format.inspect}"
    end
  end
end
