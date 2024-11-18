require 'minitest/autorun'

class CombinePDFRendererTest < Minitest::Test

  class TestRenderer
    include CombinePDF::Renderer

    def test_object(object)
      object_to_pdf(object)
    end
  end

  def test_numeric_array_to_pdf
    input = [1.234567, 0.000054, 5, -0.000099]
    expected = "[1.234567 0.000054 5 -0.000099]".b
    actual = TestRenderer.new.test_object(input)

    assert_equal(expected, actual)
  end

  def test_object_to_pdf_indirect_reference_id
    actual = TestRenderer.new.test_object(
      :indirect_reference_id => 1,
      :indirect_generation_number => 2
    )
    assert_match /^1 2 obj/, actual
    assert_match /endobj$/, actual
  end

  def test_object_to_pdf_is_reference_only
    actual = TestRenderer.new.test_object(
      :Pages => {
        :referenced_object => { :Type => :Pages, :Count => 0, :indirect_reference_id => 3 },
        :is_reference_only => true
      }
    )
    assert_match /Pages 3 0 R/, actual
  end

  def test_object_to_pdf_raw_stream_content
    actual = TestRenderer.new.test_object(
      :raw_stream_content => 'Testing'
    )
    assert_match /stream\nTesting\nendstream/, actual
  end
end
