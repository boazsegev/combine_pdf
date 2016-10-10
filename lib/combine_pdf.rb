# -*- encoding : utf-8 -*-

require 'zlib'
require 'securerandom'
require 'strscan'
require 'matrix'
require 'set'

# require the RC4 Gem
require 'rc4'

load 'combine_pdf/api.rb'
load 'combine_pdf/renderer.rb'
load 'combine_pdf/page_methods.rb'
load 'combine_pdf/basic_writer.rb'
load 'combine_pdf/decrypt.rb'
load 'combine_pdf/fonts.rb'
load 'combine_pdf/filter.rb'
load 'combine_pdf/parser.rb'
load 'combine_pdf/pdf_public.rb'
load 'combine_pdf/pdf_protected.rb'
load 'combine_pdf/exceptions.rb'

# load "combine_pdf/operations.rb"

load 'combine_pdf/version.rb'

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
#   pdf = CombinePDF.load("file.pdf")
# parse PDF files from memory:
#   pdf = CombinePDF.parse(pdf_data)
#
# == Combine/Merge PDF files or Pages
# To combine PDF files (or data):
#   pdf = CombinePDF.new
#   pdf << CombinePDF.load("file1.pdf")
#   pdf << CombinePDF.load("file2.pdf")
#   pdf.save "combined.pdf"
#
# It is possible to add only specific pages.
# in this example, only even pages will be added:
#   pdf = CombinePDF.new
#   i = 0
#   CombinePDF.load("file.pdf").pages.each do |page|
#     i += 1
#     pdf << page if i.even?
#   end
#   pdf.save "even_pages.pdf"
# Notice that adding the whole file is faster then adding each page seperately.
# == Add content to existing pages (Stamp / Watermark)
# It is possible "stamp" one PDF page using another PDF page. In this example, a company logo will be stamped over each page:
#   company_logo = CombinePDF.load("company_logo.pdf").pages[0]
#   pdf = CombinePDF.load "content_file.pdf"
#   pdf.pages.each {|page| page << company_logo}
#   pdf.save "content_with_logo.pdf"
# Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages.
# == Page Numbering
# It is possible to number the pages. in this example we will add very simple numbering:
#   pdf = CombinePDF.load "file_to_number.pdf"
#   pdf.number_pages
#   pdf.save "file_with_numbering.pdf"
#
# numbering can be done with many different options, with different formating, with or without a box object, different locations on each page and even with opacity values.
# == Writing Content
# page numbering actually adds content using the PDFWriter object (a very basic writer).
#
# in this example, all the PDF pages will be stamped, along the top, with a red box, with blue text, stating "Draft, page #".
# here is the easy way (we can even use "number_pages" without page numbers, if we wish):
#   pdf = CombinePDF.load "file_to_stamp.pdf"
#   pdf.number_pages number_format: " - Draft, page %d - ", number_location: [:top], font_color: [0,0,1], box_color: [0.4,0,0], opacity: 0.75, font_size:16
#   pdf.save "draft.pdf"
#
# in this example we will add a first page with the word "Draft", in red over a colored background:
#
#   pdf = CombinePDF.load "file.pdf"
#   pdf_first_page = pdf.pages[0]
#   mediabox = page[:CropBox] || page[:MediaBox] #copy page size
#   title_page = CombinePDF.create_page mediabox #make title page same size as first page
#   title_page.textbox "DRAFT", font_color: [0.8,0,0], font_size: :fit_text, box_color: [1,0.8,0.8], opacity: 1
#   pdf >> title_page # the >> operator adds pages at the begining
#   pdf.save "draft.pdf"
#
# font support for the writer is still in the works and is limited to extracting know fonts by location of the 14 standard fonts.
#
# == Resizing pages
#
# Using the {http://www.prepressure.com/library/paper-size PDF standards for page sizes}, it is now possible to resize
# existing PDF pages, as well as stretch and shrink their content to the new size.
#
#   pdf = CombinePDF.load "file.pdf"
#   a4_size = [0, 0, 595, 842]
#   # keep aspect ratio intact
#   pdf.pages.each {|p| p.resize a4_size}
#   pdf.save "a4.pdf"
#
#   pdf = CombinePDF.load "file.pdf"
#   a4_squared = [0, 0, 595, 595]
#   # stretch or shrink content to fit new size
#   pdf.pages.each {|p| p.resize a4_squared, false}
#   pdf.save "square.pdf"
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
# MIT
module CombinePDF
end

#########################################################
# this file is part of the CombinePDF library and the code
# is subject to the same license (MIT).
#########################################################
# PDF object types cross reference:
# Indirect objects, references, dictionaries and streams are Hash
# arrays are Array
# strings are String
# names are Symbols (String.to_sym)
# numbers are Fixnum or Float
# boolean are TrueClass or FalseClass

## test performance with:
## puts Benchmark.measure { pdf = CombinePDF.new(file); pdf.save "test.pdf" } # PDFEditor.new_pdf
## demo: file_name = "~/Ruby/pdfs/encrypted.pdf"; pdf=0; puts Benchmark.measure { pdf = CombinePDF.new(file_name); pdf.save "test.pdf" }
## at the moment... my code is terribly slow for larger files... :(
## The file saving is solved (I hope)... but file loading is an issue.
##  pdf.each_object {|obj| puts "Stream length: #{obj[:raw_stream_content].length} was registered as #{obj[:Length].is_a?(Hash)? obj[:Length][:referenced_object][:indirect_without_dictionary] : obj[:Length]}" if obj[:raw_stream_content] }
##  pdf.objects.each {|obj| puts "#{obj.class.name}: #{obj[:indirect_reference_id]}, #{obj[:indirect_generation_number]} is: #{obj[:Type] || obj[:indirect_without_dictionary]}" }
##  puts Benchmark.measure { 1000.times { (CombinePDF::PDFOperations.get_refernced_object pdf.objects, {indirect_reference_id: 100, indirect_generation_number:0}).object_id } }
##  puts Benchmark.measure { 1000.times { (pdf.objects.select {|o| o[:indirect_reference_id]== 100 && o[:indirect_generation_number] == 0})[0].object_id } }
## puts Benchmark.measure { {}.tap {|out| pdf.objects.each {|o| out[ [o[:indirect_reference_id], o[:indirect_generation_number] ] ] = o }} }
##
#### local test for CombinePDF
## file = "/Users/2Be/Ruby/pdfs/encrypted.pdf"
## puts Benchmark.measure { 1000.times { pdf = CombinePDF.new(file); pdf.save "test.pdf" } }
### gives : 2.540000   0.140000   2.680000 (  2.696524)
## puts Benchmark.measure { pdf = CombinePDF.new() ; 1000.times { pdf << CombinePDF.new(file) } ; pdf.save "test.pdf" }
### gives: 11.770000   0.090000  11.860000 ( 11.879411) #why the difference? NOT the object reference rebuilding...
### file size: 7Kb success
###### gives: 7.440000   0.100000   7.540000 (  7.536460) (!!!) with draft file size 8kb
##
#### local test by pdftk
## pdftk_path = '/Users/2Be/Ruby/pdfs/pdftk_lib/bin/pdftk'
## file_array = []
## 1000.times { file_array << file }
## puts Benchmark.measure { system ( pdftk_path + " '" + file_array.join("' '") + "' input_pw '' output 'test.pdf'" ) }
### gives: 0.000000   0.000000   3.250000 (  3.244724)
### FAILS with no output, unwilling to decrypt.
###### gives:  0.000000   0.000000   2.640000 (  2.661801) with draft file size 1.3MB (!!)
#### local test by pyton
## pyton_path = '/Users/2Be/Ruby/pdfs/pdftk_lib/join.py'
## file_array = []
## 1000.times { file_array << file }
## puts Benchmark.measure { system ( pyton_path + " -o 'test.pdf' '#{file_array.join "' '"}' " ) }
### gives 0.000000   0.000000   1.010000 (  1.147135)
### file merge FAILS with 1,000 empty pages (undecrypted)
####### gives: 0.000000   0.000000   1.770000 (  1.775513) with draft. file size 4.9MB (!!!)
