require 'bundler/setup'
require 'minitest/autorun'
require 'combine_pdf'

class CombinePDFPDFProtectedTest < Minitest::Test
  def test_to_pdf_keeps_stream_objects_that_share_content_but_differ_in_array_values
    pdf = CombinePDF.load('test/fixtures/files/shared_stream_form_xobjects.pdf')

    xobjects = CombinePDF.parse(pdf.to_pdf).pages.first[:Resources][:XObject]

    assert_equal [[0, 0, 90, 200], [110, 0, 200, 200]],
                 xobjects.values_at(:Left, :Right).map { |ref| ref[:referenced_object][:BBox] }
  end
end
