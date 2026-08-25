require 'bundler/setup'
require 'minitest/autorun'
require 'combine_pdf'

class CombinePDFParserTest < Minitest::Test
  def test_parse_does_not_change_source_encoding
    source = File.read('test/fixtures/files/sample_pdf.pdf', encoding: Encoding::UTF_8)

    CombinePDF.parse(source)

    assert_equal Encoding::UTF_8, source.encoding
  end

  def test_parse_does_not_mutate_a_chilled_source
    skip 'chilled string literals need Ruby 3.4+' if RUBY_VERSION < '3.4'

    deprecated = Warning[:deprecated]
    Warning[:deprecated] = true
    source = 'a chilled string literal'

    _, warnings = capture_io { CombinePDF::PDFParser.new(source) }

    assert_empty warnings
    assert_equal Encoding::UTF_8, source.encoding
  ensure
    Warning[:deprecated] = deprecated
  end
end
