require 'bundler/setup'
require 'minitest/autorun'
require 'combine_pdf'

describe 'CombinePDF.parse with a wrong stream Length' do
  CONTENT = 'BT /F1 12 Tf 72 720 Td (Hello) Tj ET'.freeze

  # builds a one page PDF whose content stream publishes the given Length.
  def pdf_with_length(length, closed: true)
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>\nendobj\n",
      "4 0 obj\n<< /Length #{length} >>\nstream\n#{CONTENT}\n#{closed ? 'endstream' : ''}\nendobj\n"
    ]
    out = "%PDF-1.4\n".dup
    offsets = objects.map { |object| out.bytesize.tap { out << object } }
    xref = out.bytesize
    out << "xref\n0 5\n0000000000 65535 f \n" << offsets.map { |o| format("%010d 00000 n \n", o) }.join
    out << "trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
  end

  def content_of(pdf)
    contents = pdf.pages.first[:Contents]
    contents = contents.first if contents.is_a?(Array)
    (contents[:referenced_object] || contents)[:raw_stream_content]
  end

  {
    'correct' => CONTENT.bytesize,
    'too short' => 5,
    'too long, inside the file' => CONTENT.bytesize + 20,
    'beyond the end of the file' => 5_000_000,
    'negative' => -50,
    'before the start of the file' => -5_000_000
  }.each do |description, length|
    it "reads the stream up to endstream when Length is #{description}" do
      pdf = CombinePDF.parse(pdf_with_length(length))

      assert_equal 1, pdf.pages.count
      assert_equal CONTENT, content_of(pdf)
    end
  end

  it 'raises a ParsingError when Length is beyond the end of the file and the stream is never closed' do
    error = assert_raises(CombinePDF::ParsingError) { CombinePDF.parse(pdf_with_length(5_000_000, closed: false)) }
    assert_match "wasn't properly closed", error.message
  end
end
