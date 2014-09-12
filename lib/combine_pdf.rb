# -*- encoding : utf-8 -*-
require 'zlib'
require 'securerandom'
require 'strscan'

load "combine_pdf/combine_pdf_operations.rb"
load "combine_pdf/combine_pdf_basic_writer.rb"
load "combine_pdf/combine_pdf_decrypt.rb"
load "combine_pdf/combine_pdf_fonts.rb"
load "combine_pdf/combine_pdf_filter.rb"
load "combine_pdf/combine_pdf_parser.rb"
load "combine_pdf/combine_pdf_pdf.rb"

# # will be removed one font support and font library is completed.
# require "combine_pdf/font_metrics/courier-bold_metrics.rb"
# require "combine_pdf/font_metrics/courier-boldoblique_metrics.rb"
# require "combine_pdf/font_metrics/courier-oblique_metrics.rb"
# require "combine_pdf/font_metrics/courier_metrics.rb"
# require "combine_pdf/font_metrics/helvetica-bold_metrics.rb"
# require "combine_pdf/font_metrics/helvetica-boldoblique_metrics.rb"
# require "combine_pdf/font_metrics/helvetica-oblique_metrics.rb"
# require "combine_pdf/font_metrics/helvetica_metrics.rb"
# require "combine_pdf/font_metrics/symbol_metrics.rb"
# require "combine_pdf/font_metrics/times-bold_metrics.rb"
# require "combine_pdf/font_metrics/times-bolditalic_metrics.rb"
# require "combine_pdf/font_metrics/times-italic_metrics.rb"
# require "combine_pdf/font_metrics/times-roman_metrics.rb"
# require "combine_pdf/font_metrics/zapfdingbats_metrics.rb"
# require "combine_pdf/font_metrics/metrics_dictionary.rb"





# This is a pure ruby library to combine/merge, stmap/overlay and number PDF files.
#
# You can also use this library for writing basic text content into new or existing PDF files (For authoring new PDF files look at the Prawn ruby library).
#
# here is the most basic application for the library, a one-liner that combines the PDF files and saves them:
#   (CombinePDF.new("file1.pdf") << CombinePDF.new("file2.pdf") << CombinePDF.new("file3.pdf")).save("combined.pdf")
#
# == Loading PDF data
# Loading PDF data can be done from file system or directly from the memory.
#
# Loading data from a file is easy:
#   pdf = CombinePDF.new("file.pdf")
# you can also parse PDF files from memory:
#   pdf_data = IO.read 'file.pdf' # for this demo, load a file to memory
#   pdf = CombinePDF.parse(pdf_data)
# Loading from the memory is especially effective for importing PDF data recieved through the internet or from a different authoring library such as Prawn.
#
# == Combine/Merge PDF files or Pages
# To combine PDF files (or data):
#   pdf = CombinePDF.new
#   pdf << CombinePDF.new("file1.pdf")
#   pdf << CombinePDF.new("file2.pdf")
#   pdf.save "combined.pdf"
# as demonstrated above, these can be chained for into a one-liner.
#
# you can also choose to add only specific pages.
#
# in this example, only even pages will be added:
#   pdf = CombinePDF.new
#   i = 0
#   CombinePDF.new("file.pdf").pages.each do |page|
#     i += 1
#     pdf << page if i.even?
#   end
#   pdf.save "even_pages.pdf"
# notice that adding the whole file is faster then adding each page seperately.
# == Add content to existing pages (Stamp / Watermark)
# To add content to existing PDF pages, first import the new content from an existing PDF file.
# after that, add the content to each of the pages in your existing PDF.
#
# in this example, a company logo will be stamped over each page:
#   company_logo = CombinePDF.new("company_logo.pdf").pages[0]
#   pdf = CombinePDF.new "content_file.pdf"
#   pdf.pages.each {|page| page << company_logo}
#   pdf.save "content_with_logo.pdf"
# Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages.
#
# The << operator defaults to secure injection by renaming references to avoid conflics.
#
# Less recommended, but available - for overlaying pages using compressed data that might not be editable (due to limited filter support), you can use:
#   pdf.pages(nil, false).each {|page| page << stamp_page}
#
# == Page Numbering
# adding page numbers to a PDF object or file is as simple as can be:
#   pdf = CombinePDF.new "file_to_number.pdf"
#   pdf.number_pages
#   pdf.save "file_with_numbering.pdf"
#
# numbering can be done with many different options, with different formating, with or without a box object, and even with opacity values.
# == Writing Content
# page numbering actually adds content using the PDFWriter object (a very basic writer).
#
# in this example, all the PDF pages will be stamped, along the top, with a red box, with blue text, stating "Draft, page #".
# here is the easy way (we can even use "number_pages" without page numbers, if we wish):
#   pdf = CombinePDF.new "file_to_stamp.pdf"
#   pdf.number_pages number_format: " - Draft, page %d - ", number_location: [:top], font_color: [0,0,1], box_color: [0.4,0,0], opacity: 0.75, font_size:16
#   pdf.save "draft.pdf"
#
# for demntration, it will now be coded the hard way, just so we can play more directly with some of the data.
#
#   pdf = CombinePDF.new "file_to_stamp.pdf"
#   ipage_number = 1
#   pdf.pages.each do |page|
#     # create a "stamp" PDF page with the same size as the target page
#     # we will do this because we will use this to center the box in the page
#     mediabox = page[:MediaBox]
#     # CombinePDF is pointer based...
#     # so you can add the stamp to the page and still continue to edit it's content!
#     stamp = PDFWriter.new mediabox
#     page << stamp
#     # set the visible dimensions to the CropBox, if it exists.
#     cropbox = page[:CropBox]
#     mediabox = cropbox if cropbox
#     # set stamp text
#     text = " Draft (page %d) " % page_number
#     # write the textbox
#     stamp.textbox text, x: mediabox[0]+30, y: mediabox[1]+30, width: mediabox[2]-mediabox[0]-60, height: mediabox[3]-mediabox[1]-60, font_color: [0,0,1], font_size: :fit_text, box_color: [0.4,0,0], opacity: 0.5
#   end
#   pdf.save "draft.pdf"
#
#
# font support for the writer is still in the works and is extreamly limited.
# at the moment it is best to limit the fonts to the 14 standard latin fonts (no unicode).
#
# == Decryption & Filters
#
# Some PDF files are encrypted and some are compressed (the use of filters)...
#
# There is very little support for encrypted files and very very basic and limited support for compressed files.
#
# I need help with that.
#
# == Comments and file structure
#
# If you want to help with the code, please be aware:
#
# I'm a self learned hobbiest at heart. The documentation is lacking and the comments in the code are poor guidlines.
#
# The code itself should be very straight forward, but feel free to ask whatever you want.
#
# == Credit
#
# Caige Nichols wrote an amazing RC4 gem which I used in my code.
#
# I wanted to install the gem, but I had issues with the internet and ended up copying the code itself into the combine_pdf_decrypt class file.
#
# Credit to his wonderful is given here. Please respect his license and copyright... and mine.
#
# == License
#
# GPLv3
module CombinePDF
	module_function

	# Create an empty PDF object or create a PDF object from a file (parsing the file).
	# file_name:: is the name of a file to be parsed.
	def new(file_name = "")
		raise TypeError, "couldn't parse and data, expecting type String" unless file_name.is_a? String
		return PDF.new() if file_name == ''
		PDF.new( PDFParser.new(  IO.read(file_name).force_encoding(Encoding::ASCII_8BIT) ) )
	end
	# Create a PDF object from a raw PDF data (parsing the data).
	# data:: is a string that represents the content of a PDF file.
	def parse(data)
		raise TypeError, "couldn't parse and data, expecting type String" unless data.is_a? String
		PDF.new( PDFParser.new(data) )
	end
	# makes a PDFWriter object
	#
	# PDFWriter objects reresent an empty page and have the method "textbox"
	# that adds content to that page.
	#
	# PDFWriter objects are used internally for numbering pages (by creating a PDF page
	# with the page number and "stamping" it over the existing page).
	#
	# ::mediabox an Array representing the size of the PDF document. defaults to: [0.0, 0.0, 612.0, 792.0]
	#
	# if the page is PDFWriter object as a stamp, the final size will be that of the original page.
	def create_page(mediabox = [0.0, 0.0, 612.0, 792.0])
		PDFWriter.new mediabox
	end

	# adds a correctly formatted font object to the font library.
	#
	# registered fonts will remain in the library and will only be embeded in
	# PDF objects when they are used by PDFWriter objects (for example, for numbering pages).
	#
	# this function enables plug-ins to expend the font functionality of CombinePDF.
	#
	# font_name:: a Symbol with the name of the font. if the fonts exists in the library, it will be overwritten!
	# font_metrics:: a Hash of font metrics, of the format char => {wx: char_width, boundingbox: [left_x, buttom_y, right_x, top_y]} where char == character itself (i.e. " " for space). The Hash should contain a special value :missing for the metrics of missing characters. an optional :wy might be supported in the future, for up to down fonts.
	# font_pdf_object:: a Hash in the internal format recognized by CombinePDF, that represents the font object.
	# font_cmap:: a CMap dictionary Hash) which maps unicode characters to the hex CID for the font (i.e. {"a" => "61", "z" => "7a" }).
	def register_font(font_name, font_metrics, font_pdf_object, font_cmap = nil)
		Fonts.register_font font_name, font_metrics, font_pdf_object, font_cmap
	end

	# adds an existing font (from any PDF Object) to the font library.
	#
	# returns the font on success or false on failure.
	#
	# VERY LIMITTED SUPPORT:
	# - at the moment it only imports Type0 fonts.
	# - also, to extract the Hash of the actual font object you were looking for, is not a trivial matter. I do it on the console.
	# font_name:: a Symbol with the name of the font registry. if the fonts exists in the library, it will be overwritten! 
	# font_object:: a Hash in the internal format recognized by CombinePDF, that represents the font object.
	def register_font_from_pdf_object font_name, font_object
		Fonts.register_font_from_pdf_object font_name, font_object
	end
end



#########################################################
# this file is part of the CombinePDF library and the code
# is subject to the same license (GPLv3).
#########################################################
# PDF object types cross reference:
# Indirect objects, references, dictionaries and streams are Hash
# arrays are Array
# strings are String
# names are Symbols (String.to_sym)
# numbers are Fixnum or Float
# boolean are TrueClass or FalseClass

## You can test performance with:
## puts Benchmark.measure { pdf = CombinePDF.new(file_name); pdf.save "test.pdf" } # PDFEditor.new_pdf
## demo: file_name = "/Users/2Be/Ruby/pdfs/encrypted.pdf"; pdf=0; puts Benchmark.measure { pdf = CombinePDF.new(file_name); pdf.save "test.pdf" }
## at the moment... my code it terribly slow for larger files... :(
## The file saving is solved (I hope)... but file loading is an issue.
##  pdf.each_object {|obj| puts "Stream length: #{obj[:raw_stream_content].length} was registered as #{obj[:Length].is_a?(Hash)? obj[:Length][:referenced_object][:indirect_without_dictionary] : obj[:Length]}" if obj[:raw_stream_content] }
##  pdf.objects.each {|obj| puts "#{obj.class.name}: #{obj[:indirect_reference_id]}, #{obj[:indirect_generation_number]} is: #{obj[:Type] || obj[:indirect_without_dictionary]}" }
##  puts Benchmark.measure { 1000.times { (CombinePDF::PDFOperations.get_refernced_object pdf.objects, {indirect_reference_id: 100, indirect_generation_number:0}).object_id } }
##  puts Benchmark.measure { 1000.times { (pdf.objects.select {|o| o[:indirect_reference_id]== 100 && o[:indirect_generation_number] == 0})[0].object_id } }
## puts Benchmark.measure { {}.tap {|out| pdf.objects.each {|o| out[ [o[:indirect_reference_id], o[:indirect_generation_number] ] ] = o }} }


