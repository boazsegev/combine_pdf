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
    expected = "[1.234567 0.000054 5 -0.000099]".force_encoding('BINARY')
    actual = TestRenderer.new.test_object(input)

    assert_equal(expected, actual)
  end
end
