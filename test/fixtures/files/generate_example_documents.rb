# Generates the example-document fixtures used by DocumentTextExtractorTest.
# Run inside the web container: bundle exec ruby test/fixtures/files/generate_example_documents.rb
#
# These fixtures are committed to the repo; regenerate only if the expected
# extraction keywords below change.
require "zip"

DIR = File.expand_path(__dir__)
PHRASE = "Quarterly planning highlights"

# --- TXT / MD -------------------------------------------------------------
File.write(File.join(DIR, "example.txt"), "#{PHRASE} as plain text.\n")
File.write(File.join(DIR, "example.md"), "# Notes\n\n#{PHRASE} in markdown.\n")

# --- PDF ------------------------------------------------------------------
content = "BT /F1 24 Tf 72 700 Td (#{PHRASE} in PDF) Tj ET"
objs = [
  "<< /Type /Catalog /Pages 2 0 R >>",
  "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
  "<< /Length #{content.bytesize} >>\nstream\n#{content}\nendstream",
  "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
]
pdf = +"%PDF-1.4\n"
offsets = []
objs.each_with_index do |body, i|
  offsets << pdf.bytesize
  pdf << "#{i + 1} 0 obj\n#{body}\nendobj\n"
end
xref_pos = pdf.bytesize
pdf << "xref\n0 #{objs.size + 1}\n0000000000 65535 f \n"
offsets.each { |o| pdf << format("%010d 00000 n \n", o) }
pdf << "trailer\n<< /Size #{objs.size + 1} /Root 1 0 R >>\nstartxref\n#{xref_pos}\n%%EOF"
File.binwrite(File.join(DIR, "example.pdf"), pdf)

# --- DOCX (minimal OOXML zip) --------------------------------------------
docx_path = File.join(DIR, "example.docx")
File.delete(docx_path) if File.exist?(docx_path)
Zip::File.open(docx_path, create: true) do |zip|
  zip.get_output_stream("[Content_Types].xml") do |f|
    f.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
      </Types>
    XML
  end
  zip.get_output_stream("_rels/.rels") do |f|
    f.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
      </Relationships>
    XML
  end
  zip.get_output_stream("word/document.xml") do |f|
    f.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>#{PHRASE} in DOCX</w:t></w:r></w:p>
        </w:body>
      </w:document>
    XML
  end
  # The docx gem eagerly loads word/styles.xml, so include a minimal one.
  zip.get_output_stream("word/styles.xml") do |f|
    f.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
    XML
  end
  # The gem also reads document relationships when resolving hyperlinks.
  zip.get_output_stream("word/_rels/document.xml.rels") do |f|
    f.write <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
    XML
  end
end

# --- ODT (zip with content.xml) ------------------------------------------
odt_path = File.join(DIR, "example.odt")
File.delete(odt_path) if File.exist?(odt_path)
Zip::File.open(odt_path, create: true) do |zip|
  zip.get_output_stream("content.xml") do |f|
    f.write <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <office:document-content
        xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
        <office:body><office:text>
          <text:h>#{PHRASE}</text:h>
          <text:p>in ODT</text:p>
        </office:text></office:body>
      </office:document-content>
    XML
  end
end

puts "Generated example.{txt,md,pdf,docx,odt} in #{DIR}"
