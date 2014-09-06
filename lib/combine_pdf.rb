# -*- encoding : utf-8 -*-
require 'zlib'
require 'securerandom'
require 'strscan'

require "combine_pdf/combine_pdf_operations.rb"
require "combine_pdf/combine_pdf_basic_writer.rb"
require "combine_pdf/combine_pdf_decrypt.rb"
require "combine_pdf/combine_pdf_filter.rb"
require "combine_pdf/combine_pdf_parser.rb"
require "combine_pdf/combine_pdf_pdf.rb"

require "combine_pdf/font_metrics/courier-bold_metrics.rb"
require "combine_pdf/font_metrics/courier-boldoblique_metrics.rb"
require "combine_pdf/font_metrics/courier-oblique_metrics.rb"
require "combine_pdf/font_metrics/courier_metrics.rb"
require "combine_pdf/font_metrics/helvetica-bold_metrics.rb"
require "combine_pdf/font_metrics/helvetica-boldoblique_metrics.rb"
require "combine_pdf/font_metrics/helvetica-oblique_metrics.rb"
require "combine_pdf/font_metrics/helvetica_metrics.rb"
require "combine_pdf/font_metrics/symbol_metrics.rb"
require "combine_pdf/font_metrics/times-bold_metrics.rb"
require "combine_pdf/font_metrics/times-bolditalic_metrics.rb"
require "combine_pdf/font_metrics/times-italic_metrics.rb"
require "combine_pdf/font_metrics/times-roman_metrics.rb"
require "combine_pdf/font_metrics/zapfdingbats_metrics.rb"

require "combine_pdf/font_metrics/metrics_dictionary.rb"




# This is a pure ruby library to merge PDF files.
# In the future, this library will also allow stamping and watermarking PDFs (it allows this now, only with some issues).
#
# PDF objects can be used to combine or to inject data.
# == Combine/Merge PDF files or Pages
# To combine PDF files (or data):
#   pdf = CombinePDF.new
#   pdf << CombinePDF.new("file1.pdf") # one way to combine, very fast.
#   pdf << CombinePDF.new("file2.pdf")
#   pdf.save "combined.pdf"
# or even a one liner:
#   (CombinePDF.new("file1.pdf") << CombinePDF.new("file2.pdf") << CombinePDF.new("file3.pdf")).save("combined.pdf")
# you can also add just odd or even pages:
#   pdf = CombinePDF.new
#   i = 0
#   CombinePDF.new("file.pdf").pages.each do |page
#     i += 1
#     pdf << page if i.even?
#   end
#   pdf.save "even_pages.pdf"
# notice that adding all the pages one by one is slower then adding the whole file.
# == Add content to existing pages (Stamp / Watermark)
# To add content to existing PDF pages, first import the new content from an existing PDF file.
# after that, add the content to each of the pages in your existing PDF.
#
# in this example, we will add a company logo to each page:
#   company_logo = CombinePDF.new("company_logo.pdf").pages[0]
#   pdf = CombinePDF.new "content_file.pdf"
#   pdf.pages.each {|page| page << company_logo} # notice the << operator is on a page and not a PDF object.
#   pdf.save "content_with_logo.pdf"
# Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages.
#
# The << operator defaults to secure injection by renaming references to avoid conflics. For overlaying pages using compressed data that might not be editable (due to limited filter support), you can use:
#   pdf.pages(nil, false).each {|page| page << stamp_page}
#
#
# Notice that page objects are Hash class objects and the << operator was added to the Page instances without altering the class.
#
# == Page Numbering
# adding page numbers to a PDF object or file is as simple as can be:
#   pdf = CombinePDF.new "file_to_number.pdf"
#   pdf.number_pages
#   pdf.save "file_with_numbering.pdf"
#
# numbering can be done with many different options, with different formating, with or without a box object, and even with opacity values.
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


