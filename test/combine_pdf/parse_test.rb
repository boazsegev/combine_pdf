require 'minitest/autorun'

describe 'CombinePDF.parse' do
  let(:pdf_string) { CombinePDF.load('test/fixtures/files/sample_pdf.pdf').to_pdf.freeze }

  subject { CombinePDF.parse(pdf_string) }

  it 'parses the PDF' do
    assert_instance_of CombinePDF::PDF, subject
  end
end
