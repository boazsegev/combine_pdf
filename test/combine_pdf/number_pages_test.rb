require 'minitest/autorun'
require 'combine_pdf'

describe 'CombinePDF::PDF#number_pages' do
  # Helper that returns the page-number stamp stream (the last entry of the
  # page's :Contents array, i.e. the one added by `number_pages`).
  def stamp_stream(page)
    contents = page[:Contents]
    last = contents.is_a?(Array) ? contents.last : contents
    last = last[:referenced_object] if last.is_a?(Hash) && last[:referenced_object]
    last[:raw_stream_content].to_s
  end

  # Extracts the first "x y Td" pair (text positioning operator) from a
  # PDF content stream. Returns the float pair as [x, y].
  def text_position(stream)
    match = stream.match(/(\-?\d+(?:\.\d+)?)\s+(\-?\d+(?:\.\d+)?)\s+Td/)
    [match[1].to_f, match[2].to_f] if match
  end

  # Extracts the first "m" (moveto) operator from a content stream.
  # Used to find the starting point of a drawn box.
  def first_box_move(stream)
    match = stream.match(/(\-?\d+(?:\.\d+)?)\s+(\-?\d+(?:\.\d+)?)\s+m/)
    [match[1].to_f, match[2].to_f] if match
  end

  describe 'placement on an A4 page' do
    let(:pdf) { CombinePDF.new }

    before do
      pdf << CombinePDF.create_page([0, 0, 595.3, 841.9])
    end

    it 'places the bottom margin at exactly margin_from_height from the bottom edge' do
      pdf.number_pages location: [:bottom_right], font_size: 15,
                       border_width: 1, box_color: [0.8, 0.8, 0.8]

      stream = stamp_stream(pdf.pages[0])
      x, y = first_box_move(stream)

      # The first move should put us at the bottom of the rounded box. Its y
      # coordinate must equal `margin_from_height` (default 45) — i.e. 45pt
      # from the page bottom edge — regardless of page format.
      assert_in_delta 45, y, 0.5,
        "expected bottom of stamp box at y=45 (margin_from_height), got y=#{y}"
    end

    it 'places the right edge at exactly margin_from_side from the right edge' do
      pdf.number_pages location: [:bottom_right], font_size: 15,
                       border_width: 1, box_color: [0.8, 0.8, 0.8]

      stream = stamp_stream(pdf.pages[0])
      # find the largest x coordinate in the stream — that is the right edge
      # of the rounded box.
      max_x = stream.scan(/(\d+(?:\.\d+)?)\s+\d+(?:\.\d+)?\s+[ml]/).flatten.map(&:to_f).max

      page_width = 595.3
      assert_in_delta page_width - 15, max_x, 0.5,
        "expected right edge at #{page_width - 15} (page width - margin_from_side), got #{max_x}"
    end

    it 'places the top margin symmetrically with margin_from_height from the top edge' do
      pdf.number_pages location: [:top_right], font_size: 15,
                       border_width: 1, box_color: [0.8, 0.8, 0.8]

      stream = stamp_stream(pdf.pages[0])
      # The largest y coordinate in the stream is the top edge of the box.
      max_y = stream.scan(/\d+(?:\.\d+)?\s+(\d+(?:\.\d+)?)\s+[ml]/).flatten.map(&:to_f).max

      page_height = 841.9
      assert_in_delta page_height - 45, max_y, 0.5,
        "expected top edge at #{page_height - 45} (page height - margin_from_height), got #{max_y}"
    end
  end

  describe 'placement on a Letter page' do
    let(:pdf) { CombinePDF.new }

    before do
      pdf << CombinePDF.create_page([0, 0, 612.0, 792.0])
    end

    it 'places the bottom margin at exactly margin_from_height from the bottom edge' do
      pdf.number_pages location: [:bottom_right], font_size: 15,
                       border_width: 1, box_color: [0.8, 0.8, 0.8]

      stream = stamp_stream(pdf.pages[0])
      _x, y = first_box_move(stream)

      assert_in_delta 45, y, 0.5,
        "expected bottom of stamp box at y=45 on Letter as well, got y=#{y}"
    end

    it 'places the right edge at exactly margin_from_side from the right edge' do
      pdf.number_pages location: [:bottom_right], font_size: 15,
                       border_width: 1, box_color: [0.8, 0.8, 0.8]

      stream = stamp_stream(pdf.pages[0])
      max_x = stream.scan(/(\d+(?:\.\d+)?)\s+\d+(?:\.\d+)?\s+[ml]/).flatten.map(&:to_f).max

      page_width = 612.0
      assert_in_delta page_width - 15, max_x, 0.5,
        "expected right edge at #{page_width - 15} on Letter, got #{max_x}"
    end
  end

  describe 'placement on a page with a non-zero MediaBox origin' do
    let(:pdf) { CombinePDF.new }

    before do
      # An A4 page whose MediaBox does not start at (0, 0).
      page = CombinePDF.create_page
      page[:MediaBox] = [10, 20, 605.3, 861.9]
      pdf << page
    end

    it 'offsets the stamp by the MediaBox origin, keeping the requested margins' do
      pdf.number_pages location: [:bottom_right], font_size: 15,
                       border_width: 1, box_color: [0.8, 0.8, 0.8]

      stream = stamp_stream(pdf.pages[0])
      _x, y = first_box_move(stream)
      max_x = stream.scan(/(\d+(?:\.\d+)?)\s+\d+(?:\.\d+)?\s+[ml]/).flatten.map(&:to_f).max

      # Bottom margin: 20 (origin) + 45 (margin_from_height)
      assert_in_delta 65, y, 0.5,
        "expected bottom y at 65 (origin + margin), got #{y}"
      # Right edge: 605.3 (mediabox[2]) - 15 (margin_from_side)
      assert_in_delta 590.3, max_x, 0.5,
        "expected right edge at 590.3 (mediabox[2] - margin), got #{max_x}"
    end
  end

  describe 'placement on a page with an indirect MediaBox reference' do
    let(:pdf) { CombinePDF.new }

    before do
      page = CombinePDF.create_page
      # Simulate an A4 MediaBox stored as an indirect reference (this happens
      # with some real-world PDFs that share a single MediaBox object across
      # pages via the page tree).
      page[:MediaBox] = {
        is_reference_only: true,
        referenced_object: { indirect_reference_id: 99,
                             indirect_generation_number: 0 },
      }
      page[:MediaBox][:referenced_object][:indirect_without_dictionary] =
        [0, 0, 595.3, 841.9]
      pdf << page
    end

    it 'resolves the indirect reference and places the stamp on the actual page size' do
      pdf.number_pages location: [:bottom_right], font_size: 15,
                       border_width: 1, box_color: [0.8, 0.8, 0.8]

      stream = stamp_stream(pdf.pages[0])
      _x, y = first_box_move(stream)
      max_x = stream.scan(/(\d+(?:\.\d+)?)\s+\d+(?:\.\d+)?\s+[ml]/).flatten.map(&:to_f).max

      assert_in_delta 45, y, 0.5,
        "expected bottom y at 45 with indirect MediaBox, got #{y}"
      assert_in_delta 595.3 - 15, max_x, 0.5,
        "expected right edge at #{595.3 - 15} with indirect MediaBox, got #{max_x}"
    end
  end
end
