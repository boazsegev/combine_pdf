require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/around/spec'
require 'combine_pdf'

describe 'CombinePDF RangeError fix' do
  describe 'issue #205 - stream length exceeds bounds' do
    it 'should parse PDF with invalid stream length without raising RangeError' do
      # Test with the PDF that caused the original issue
      pdf_path = 'test/fixtures/files/test-index-out-of-range-error-corrupted.pdf'

      # Should not raise RangeError
      pdf_data = File.binread(pdf_path)

      # This should work without throwing RangeError: index out of range
      parsed_pdf = CombinePDF.parse(pdf_data, allow_optional_content: true)

      # Should successfully parse
      assert_instance_of CombinePDF::PDF, parsed_pdf
      assert_equal 1, parsed_pdf.pages.length

      # Should have a valid page with MediaBox
      page = parsed_pdf.pages.first
      assert page[:MediaBox], "Page should have MediaBox"
      assert_equal [0, 0, 595.28, 841.89], page[:MediaBox]
    end

    it 'should handle RangeError gracefully in stream parsing' do
      # This test verifies that even if a RangeError occurs, we handle it gracefully
      pdf_path = 'test/fixtures/files/test-index-out-of-range-error-corrupted.pdf'
      pdf_data = File.binread(pdf_path)

      # Should not crash with RangeError: index out of range
      begin
        result = CombinePDF.parse(pdf_data, allow_optional_content: true)
        assert_instance_of CombinePDF::PDF, result
      rescue RangeError => e
        flunk "Should not raise RangeError: #{e.message}"
      end
    end
  end
end
