# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################

module CombinePDF
  # Limited Unicode Support (font dependent)!
  #
  # The PDFWriter class is a subclass of Hash and represents a PDF Page object.
  #
  # Writing on this Page is done using the textbox function.
  #
  # Setting the page dimensions can be either at the new or using the mediabox method. New pages default to size A4, which is: [0, 0, 595.3, 841.9].
  #
  # Once the Page is completed (the last text box was added),
  # we can insert the page to a CombinePDF object.
  #
  # We can either insert the PDFWriter as a new page:
  #   pdf = CombinePDF.new
  #   new_page = CombinePDF.create_page # => PDFWriter object
  #   new_page.textbox "some text"
  #   pdf << new_page
  #   pdf.save "file_with_new_page.pdf"
  #
  # Or we can use the Page_Methods methods to write an overlay (stamp / watermark) over existing pages:
  #   pdf = CombinePDF.new
  #   new_page = PDFWriter.new "some_file.pdf"
  #   pdf.pages.each {|page| page.textbox "Draft", opacity: 0.4 }
  #   pdf.save "stamped_file.pdf"
  class PDFWriter < Hash
    # create a new PDFWriter object.
    #
    # mediabox:: the PDF page size in PDF points. defaults to [0, 0, 612.0, 792.0] (US Letter)
    def initialize(mediabox = [0, 0, 612.0, 792.0])
      # indirect_reference_id, :indirect_generation_number
      @contents = ''
      @base_font_name = 'Writer' + SecureRandom.hex(7) + 'PDF'
      self[:Type] = :Page
      self[:indirect_reference_id] = 0
      self[:Resources] = {}
      self[:Contents] = { is_reference_only: true, referenced_object: { indirect_reference_id: 0, raw_stream_content: @contents } }
      self[:MediaBox] = mediabox
    end

    # includes the PDF Page_Methods module, including all page methods (textbox etc').
    include Page_Methods
  end
end
