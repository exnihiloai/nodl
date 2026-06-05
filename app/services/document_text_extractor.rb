require "pdf-reader"
require "docx"
require "zip"
require "nokogiri"

# Extracts plain text from an uploaded example document so it can be supplied
# to the AI as additional context. Uses pure-Ruby parsers only (no LibreOffice,
# Pandoc, or other native binaries) to keep the Docker image lightweight.
#
# Extraction is best-effort: a malformed or unreadable file returns an empty
# string rather than raising, so one bad example never fails a whole document
# generation run.
class DocumentTextExtractor
  PLAIN_TEXT_TYPES = %w[text/plain text/markdown].freeze
  PDF_TYPE = "application/pdf".freeze
  DOCX_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document".freeze
  ODT_TYPE = "application/vnd.oasis.opendocument.text".freeze

  def self.extract(attachment)
    new.extract(attachment)
  end

  def extract(attachment)
    return "" if attachment.blank?
    return "" if attachment.respond_to?(:attached?) && !attachment.attached?

    attachment.open do |tempfile|
      case attachment.content_type
      when *PLAIN_TEXT_TYPES
        File.read(tempfile.path, encoding: "UTF-8")
      when PDF_TYPE
        extract_pdf(tempfile.path)
      when DOCX_TYPE
        extract_docx(tempfile.path)
      when ODT_TYPE
        extract_odt(tempfile.path)
      else
        ""
      end
    end
  rescue StandardError => error
    Rails.logger.error("Text extraction failed for #{attachment.filename}: #{error.message}")
    ""
  end

  private

  def extract_pdf(path)
    reader = PDF::Reader.new(path)
    reader.pages.map(&:text).join("\n\n")
  end

  def extract_docx(path)
    doc = Docx::Document.open(path)
    doc.paragraphs.map(&:text).join("\n\n")
  end

  def extract_odt(path)
    Zip::File.open(path) do |zip_file|
      entry = zip_file.find_entry("content.xml")
      return "" unless entry

      xml_content = entry.get_input_stream.read
      doc = Nokogiri::XML(xml_content)
      # Paragraph (text:p) and heading (text:h) elements hold the body copy.
      doc.xpath("//text:p | //text:h").map(&:text).join("\n\n")
    end
  end
end
