# -*- encoding : utf-8 -*-
# use under GPLv3 terms only

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





# This is a pure ruby library to combine/merge, stmap/overlay and number PDF files - as well as to create tables (ment for indexing combined files).
#
# You can also use this library for writing basic text content into new or existing PDF files (For authoring new PDF files look at the Prawn ruby library).
#
# here is the most basic application for the library, a one-liner that combines the PDF files and saves them:
#   (CombinePDF.new("file1.pdf") << CombinePDF.new("file2.pdf") << CombinePDF.new("file3.pdf")).save("combined.pdf")
#
# == Loading PDF data
# Loading PDF data can be done from file system or directly from the memory.
#
# Load data from a file:
#   pdf = CombinePDF.new("file.pdf")
# parse PDF files from memory:
#   pdf = CombinePDF.parse(pdf_data)
#
# == Combine/Merge PDF files or Pages
# To combine PDF files (or data):
#   pdf = CombinePDF.new
#   pdf << CombinePDF.new("file1.pdf")
#   pdf << CombinePDF.new("file2.pdf")
#   pdf.save "combined.pdf"
#
# It is possible to add only specific pages.
# in this example, only even pages will be added:
#   pdf = CombinePDF.new
#   i = 0
#   CombinePDF.new("file.pdf").pages.each do |page|
#     i += 1
#     pdf << page if i.even?
#   end
#   pdf.save "even_pages.pdf"
# Notice that adding the whole file is faster then adding each page seperately.
# == Add content to existing pages (Stamp / Watermark)
# It is possible "stamp" one PDF page using another PDF page. In this example, a company logo will be stamped over each page:
#   company_logo = CombinePDF.new("company_logo.pdf").pages[0]
#   pdf = CombinePDF.new "content_file.pdf"
#   pdf.pages.each {|page| page << company_logo}
#   pdf.save "content_with_logo.pdf"
# Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages.
# == Page Numbering
# It is possible to number the pages. in this example we will add very simple numbering:
#   pdf = CombinePDF.new "file_to_number.pdf"
#   pdf.number_pages
#   pdf.save "file_with_numbering.pdf"
#
# numbering can be done with many different options, with different formating, with or without a box object, different locations on each page and even with opacity values.
# == Writing Content
# page numbering actually adds content using the PDFWriter object (a very basic writer).
#
# in this example, all the PDF pages will be stamped, along the top, with a red box, with blue text, stating "Draft, page #".
# here is the easy way (we can even use "number_pages" without page numbers, if we wish):
#   pdf = CombinePDF.new "file_to_stamp.pdf"
#   pdf.number_pages number_format: " - Draft, page %d - ", number_location: [:top], font_color: [0,0,1], box_color: [0.4,0,0], opacity: 0.75, font_size:16
#   pdf.save "draft.pdf"
#
# in this example we will add a first page with the word "Draft", in red over a colored background:
#
#   pdf = CombinePDF.new "file.pdf"
#   pdf_first_page = pdf.pages[0]
#   mediabox = page[:CropBox] || page[:MediaBox] #copy page size
#   title_page = CombinePDF.create_page mediabox #make title page same size as first page
#   title_page.textbox "DRAFT", font_color: [0.8,0,0], font_size: :fit_text, box_color: [1,0.8,0.8], opacity: 1
#   pdf >> title_page # the >> operator adds pages at the begining
#   pdf.save "draft.pdf"
#
# font support for the writer is still in the works and is limited to extracting know fonts by location.
# at the moment it is best to limit the fonts to the 14 standard latin fonts (no unicode).
#
# == Decryption & Filters
#
# Some PDF files are encrypted and some are compressed (the use of filters)... not all files can be opened, merged, stamped or used and stamps.
# == Comments and file structure
#
# If you want to help with the code, please be aware:
#
# The code itself should be very straight forward, but feel free to ask whatever you want.
#
# == Credit
#
# Caige Nichols wrote an amazing RC4 gem which I reference in my code.
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
		raise TypeError, "couldn't parse and data, expecting type String" unless file_name.is_a?(String) || file_name.is_a?(Pathname)
		return PDF.new() if file_name == ''
		PDF.new( PDFParser.new(  IO.read(file_name).force_encoding(Encoding::ASCII_8BIT) ) )
	end
	alias_method :new, :load

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
	def create_page(mediabox = [0, 0, 595.3, 841.9])
		PDFWriter.new mediabox
	end

	# makes a PDF object containing a table
	#
	# all the pages in this PDF object are PDFWriter objects and are
	# writable using the texbox function (should you wish to add a title, or more info)
	#
	# the main intended use of this method is to create indexes (a table of contents) for merged data.
	#
	# example:
	#   pdf = CombinePDF.create_table headers: ["header 1", "another header"], table_data: [ ["this is one row", "with two columns"] , ["this is another row", "also two columns", "the third will be ignored"] ]
	#   pdf.save "table_file.pdf"
	#
	# accepts a Hash with any of the following keys as well as any of the PDFWriter#textbox options:
	# headers:: an Array of strings with the headers (will be repeated every page).
	# table_data:: as Array of Arrays, each containing a string for each column. the first row sets the number of columns. extra columns will be ignored.
	# font:: a registered or standard font name (see PDFWriter). defaults to nil (:Helvetica).
	# header_font:: a registered or standard font name for the headers (see PDFWriter). defaults to nil (the font for all the table rows).
	# max_font_size:: the maximum font size. if the string doesn't fit, it will be resized. defaults to 14.
	# column_widths:: an array of relative column widths ([1,2] will display only the first two columns, the second twice as big as the first). defaults to nil (even widths).
	# header_color:: the header color. defaults to [0.8, 0.8, 0.8] (light gray).
	# main_color:: main row color. defaults to nil (transparent / white).
	# alternate_color:: alternate row color. defaults to [0.95, 0.95, 0.95] (very light gray).
	# font_color:: font color. defaults to [0,0,0] (black).
	# border_color:: border color. defaults to [0,0,0] (black).
	# border_width:: border width in PDF units. defaults to 1.
	# header_align:: the header text alignment within each column (:right, :left, :center). defaults to :center.
	# row_align:: the row text alignment within each column. defaults to :left (:right for RTL table).
	# direction:: the table's writing direction (:ltr or :rtl). this reffers to the direction of the columns and doesn't effect text (rtl text is automatically recognized). defaults to :ltr.
	# rows_per_page:: the number of rows per page, INCLUDING the header row. deafults to 25.
	# page_size:: the size of the page in PDF points. defaults to [0, 0, 595.3, 841.9] (A4).
	def create_table (options = {})
		defaults = {
			headers: nil,
			table_data: [[]],
			font: nil,
			header_font: nil,
			max_font_size: 14,
			column_widths: nil,
			header_color: [0.8, 0.8, 0.8],
			main_color: nil,
			alternate_color: [0.95, 0.95, 0.95],
			font_color: [0,0,0],
			border_color: [0,0,0],
			border_width: 1,
			header_align: :center,
			row_align: nil,
			direction: :ltr,
			rows_per_page: 25,
			page_size: [0, 0, 595.3, 841.9] #A4
		}
		options = defaults.merge options
		options[:header_font] = options[:font] unless options[:header_font]
		options[:row_align] ||= ( (options[:direction] == :rtl) ? :right : :left )
		# assert table_data is an array of arrays
		return false unless (options[:table_data].select {|r| !r.is_a?(Array) }).empty?
		# compute sizes
		page_size = options[:page_size]
		top = page_size[3] * 0.9
		height = page_size[3] * 0.8 / options[:rows_per_page]
		from_side = page_size[2] * 0.1
		width = page_size[2] * 0.8
		columns = options[:table_data][0].length
		column_widths = []
		columns.times {|i| column_widths << (width/columns) }
		if options[:column_widths]
			scale = 0
			options[:column_widths].each {|w| scale += w}
			column_widths = []
			options[:column_widths].each { |w|  column_widths << (width*w/scale) }
		end
		column_widths = column_widths.reverse if options[:direction] == :rtl
		# set pdf object and start writing the data
		table = PDF.new()
		page = nil
		rows_per_page = options[:rows_per_page]
		row_number = rows_per_page + 1

		options[:table_data].each do |row_data|
			if row_number > rows_per_page
				page = create_page page_size
				table << page
				row_number = 1
				# add headers
				if options[:headers]
					x = from_side
					headers = options[:headers]
					headers = headers.reverse if options[:direction] == :rtl
					column_widths.each_index do |i|
						text = headers[i].to_s
						page.textbox text, {x: x, y: (top - (height*row_number)), width: column_widths[i], height: height, box_color: options[:header_color], text_align: options[:header_align] }.merge(options).merge({font: options[:header_font]})
						x += column_widths[i]
					end
					row_number += 1
				end
			end
			x = from_side
			row_data = row_data.reverse if options[:direction] == :rtl
			column_widths.each_index do |i|
				text = row_data[i].to_s
				box_color = options[:main_color]
				box_color = options[:alternate_color] if options[:alternate_color] && row_number.odd?
				page.textbox text, {x: x, y: (top - (height*row_number)), width: column_widths[i], height: height, box_color: box_color, text_align: options[:row_align]}.merge(options)
				x += column_widths[i]
			end			
			row_number += 1
		end
		table
	end
	alias_method :create_tabe, :new_table

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
	alias_method :register_font_from_pdf_object, :register_existing_font
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


