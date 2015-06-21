# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################






module CombinePDF

	# PDF class is the PDF object that can save itself to
	# a file and that can be used as a container for a full
	# PDF file data, including version, information etc'.
	#
	# PDF objects can be used to combine or to inject data.
	# == Combine/Merge PDF files or Pages
	# To combine PDF files (or data):
	#   pdf = CombinePDF.new
	#   pdf << CombinePDF.load("file1.pdf") # one way to combine, very fast.
	#   pdf << CombinePDF.load("file2.pdf")
	#   pdf.save "combined.pdf"
	# or even a one liner:
	#   (CombinePDF.load("file1.pdf") << CombinePDF.load("file2.pdf") << CombinePDF.load("file3.pdf")).save("combined.pdf")
	# you can also add just odd or even pages:
	#   pdf = CombinePDF.new
	#   i = 0
	#   CombinePDF.load("file.pdf").pages.each do |page|
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
	#   company_logo = CombinePDF.load("company_logo.pdf").pages[0]
	#   pdf = CombinePDF.load "content_file.pdf"
	#   pdf.pages.each {|page| page << company_logo} # notice the << operator is on a page and not a PDF object.
	#   pdf.save "content_with_logo.pdf"
	# Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages.
	#
	# The << operator defaults to secure injection by renaming references to avoid conflics. For overlaying pages using compressed data that might not be editable (due to limited filter support), you can use:
	#   pdf.pages(nil, false).each {|page| page << stamp_page}
	#
	# == Page Numbering
	# adding page numbers to a PDF object or file is as simple as can be:
	#   pdf = CombinePDF.load "file_to_number.pdf"
	#   pdf.number_pages
	#   pdf.save "file_with_numbering.pdf"
	#
	# numbering can be done with many different options, with different formating, with or without a box object, and even with opacity values.
	#
	# == Loading PDF data
	# Loading PDF data can be done from file system or directly from the memory.
	#
	# Loading data from a file is easy:
	#   pdf = CombinePDF.load("file.pdf")
	# you can also parse PDF files from memory:
	#   pdf_data = IO.read 'file.pdf' # for this demo, load a file to memory
	#   pdf = CombinePDF.parse(pdf_data)
	# Loading from the memory is especially effective for importing PDF data recieved through the internet or from a different authoring library such as Prawn.
	class PDF

		# lists the Hash keys used for PDF objects
		#
		# the CombinePDF library doesn't use special classes for its objects (PDFPage class, PDFStream class or anything like that).
		#
		# there is only one PDF class which represents the whole of the PDF file.
		#
		# this Hash lists the private Hash keys that the CombinePDF library uses to
		# differentiate between complex PDF objects.
		PRIVATE_HASH_KEYS = [:indirect_reference_id, :indirect_generation_number, :raw_stream_content, :is_reference_only, :referenced_object, :indirect_without_dictionary]

		# the objects attribute is an Array containing all the PDF sub-objects for te class.
		attr_reader :objects
		# the info attribute is a Hash that sets the Info data for the PDF.
		# use, for example:
		#   pdf.info[:Title] = "title"
		attr_reader :info
		# set/get the PDF version of the file (1.1-1.7) - shuold be type Float.
		attr_accessor :version
		# the viewer_preferences attribute is a Hash that sets the ViewerPreferences data for the PDF.
		# use, for example:
		#   pdf.viewer_preferences[:HideMenubar] = true
		attr_reader :viewer_preferences

		def initialize (parser = nil)
			# default before setting
			@objects = []
			@version = 0
			@viewer_preferences, @info  = {}, {}
			parser ||= PDFParser.new("")
			raise TypeError, "initialization error, expecting CombinePDF::PDFParser or nil, but got #{parser.class.name}" unless parser.is_a? PDFParser
			@objects = parser.parse
			# remove any existing id's
			remove_old_ids
			# set data from parser
			@version = parser.version if parser.version.is_a? Float
			@info = parser.info_object || {}

			# general globals
			@set_start_id = 1
			@info[:Producer] = "Ruby CombinePDF #{CombinePDF::VERSION} Library"
			@info.delete :CreationDate
			@info.delete :ModDate
		end

		# adds a new page to the end of the PDF object.
		#
		# returns the new page object.
		def new_page(mediabox = [0, 0, 595.3, 841.9], location = -1)
			p = PDFWriter.new(mediabox)
			insert(-1, p )
			p
		end

		# get the title for the pdf
		# The title is stored in the information dictionary and isn't required
		def title
			return @info[:Title]
		end
		# set the title for the pdf
		# The title is stored in the information dictionary and isn't required
		# new_title:: a string that is the new author value.
		def title=(new_title = nil)
			@info[:Title] = new_title
		end
		# get the author value for the pdf.
		# The author is stored in the information dictionary and isn't required
		def author
			return @info[:Author]
		end
		# set the author value for the pdf.
		# The author is stored in the information dictionary and isn't required
		#
		# new_title:: a string that is the new author value.
		def author=(new_author = nil)
			@info[:Author] = new_author
		end

		# Save the PDF to file.
		# 
		# file_name:: is a string or path object for the output.
		#
		# **Notice!** if the file exists, it **WILL** be overwritten.
		def save(file_name, options = {})
			IO.binwrite file_name, to_pdf(options)
		end

		# Formats the data to PDF formats and returns a binary string that represents the PDF file content.
		#
		# This method is used by the save(file_name) method to save the content to a file.
		#
		# use this to export the PDF file without saving to disk (such as sending through HTTP ect').
		def to_pdf options = {}
			#reset version if not specified
			@version = 1.5 if @version.to_f == 0.0
			#set creation date for merged file
			@info[:CreationDate] = Time.now.strftime "D:%Y%m%d%H%M%S%:::z'00"
			#rebuild_catalog
			catalog = rebuild_catalog_and_objects
			# add ID and generation numbers to objects
			renumber_object_ids

			out = []
			xref = []
			indirect_object_count = 1 #the first object is the null object
			#write head (version and binanry-code)
			out << "%PDF-#{@version.to_s}\n%\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\x00".force_encoding(Encoding::ASCII_8BIT)

			#collect objects and set xref table locations
			loc = 0
			out.each {|line| loc += line.bytesize + 1}
			@objects.each do |o|
				indirect_object_count += 1
				xref << loc
				out << object_to_pdf(o)
				loc += out.last.bytesize + 1
			end
			xref_location = loc
			# xref_location = 0
			# out.each { |line| xref_location += line.bytesize + 1}
			out << "xref\n0 #{(indirect_object_count).to_s}\n0000000000 65535 f \n"
			xref.each {|offset| out << ( out.pop + ("%010d 00000 n \n" % offset) ) }
			out << out.pop + "trailer"
			out << "<<\n/Root #{false || "#{catalog[:indirect_reference_id]} #{catalog[:indirect_generation_number]} R"}"
			out << "/Size #{indirect_object_count.to_s}"
			if @info.is_a?(Hash)
				PRIVATE_HASH_KEYS.each {|key| @info.delete key} # make sure the dictionary is rendered inline, without stream
				@info[:CreationDate] = @info[:ModDate] = Time.now.strftime "D:%Y%m%d%H%M%S%:::z'00"
				@info[:Subject] = options[:subject] if options[:subject]
				@info[:Producer] = options[:producer] if options[:producer]
				out << "/Info #{object_to_pdf @info}"
			end
			out << ">>\nstartxref\n#{xref_location.to_s}\n%%EOF"
			# when finished, remove the numbering system and keep only pointers
			remove_old_ids
			# output the pdf stream
			out.join("\n").force_encoding(Encoding::ASCII_8BIT)
		end

		# this method returns all the pages cataloged in the catalog.
		#
		# if no catalog is passed, it seeks the existing catalog(s) and searches
		# for any registered Page objects.
		#
		# Page objects are Hash class objects. the page methods are added using a mixin or inheritance.
		#
		# catalogs:: a catalog, or an Array of catalog objects. defaults to the existing catalog.
		def pages(catalogs = nil)
			page_list = []
			catalogs ||= get_existing_catalogs

			if catalogs.is_a?(Array)
				catalogs.each {|c| page_list.push *( pages(c) ) unless c.nil?}
			elsif catalogs.is_a?(Hash)
				if catalogs[:is_reference_only]
					if catalogs[:referenced_object]
						page_list.push *( pages(catalogs[:referenced_object]) )
					else
						warn "couldn't follow reference!!! #{catalogs} not found!"
					end
				else
					case catalogs[:Type]
					when :Page
						page_list << catalogs
					when :Pages
						page_list.push *(pages(catalogs[:Kids])) unless catalogs[:Kids].nil?
					when :Catalog
						page_list.push *(pages(catalogs[:Pages])) unless catalogs[:Pages].nil?
					end
				end
			end
			page_list
		end

		# returns an array with the different fonts used in the file.
		#
		# Type0 font objects ( "font[:Subtype] == :Type0" ) can be registered with the font library
		# for use in PDFWriter objects (font numbering / table creation etc').
		# @param limit_to_type0 [true,false] limits the list to type0 fonts.
		def fonts(limit_to_type0 = false)
			fonts_array = []
			pages.each do |p|
				p[:Resources][:Font].values.each do |f|
					f = f[:referenced_object] if f[:referenced_object]
					if (limit_to_type0 || f[:Subtype] = :Type0) && f[:Type] == :Font  && !fonts_array.include?(f)
						fonts_array << f
					end
				end
			end
			fonts_array
		end

		# add the pages (or file) to the PDF (combine/merge) and RETURNS SELF, for nesting.
		# for example:
		#
		#   pdf = CombinePDF.new "first_file.pdf"
		#
		#   pdf << CombinePDF.new "second_file.pdf"
		#
		#   pdf.save "both_files_merged.pdf"
		# data:: is PDF page (Hash), and Array of PDF pages or a parsed PDF object to be added.
		def << (data)
			insert -1, data
		end

		# add the pages (or file) to the BEGINNING of the PDF (combine/merge) and RETURNS SELF for nesting operators.
		# for example:
		#
		#   pdf = CombinePDF.new "second_file.pdf"
		#
		#   pdf >> CombinePDF.new "first_file.pdf"
		#
		#   pdf.save "both_files_merged.pdf"
		# data:: is PDF page (Hash), and Array of PDF pages or a parsed PDF object to be added.
		def >> (data)
			insert 0, data
		end

		# add PDF pages (or PDF files) into a specific location.
		#
		# returns the new pages Array! (unlike `#<<`, doesn't return self!)
		#
		# location:: the location for the added page(s). Could be any number. negative numbers represent a count backwards (-1 being the end of the page array and 0 being the begining). if the location is beyond bounds, the pages will be added to the end of the PDF object (or at the begining, if the out of bounds was a negative number).
		# data:: a PDF page, a PDF file (CombinePDF.new "filname.pdf") or an array of pages (CombinePDF.new("filname.pdf").pages[0..3]).
		def insert(location, data)
			pages_to_add = nil
			if data.is_a? PDF
		 		@version = [@version, data.version].max
				pages_to_add = data.pages
			elsif data.is_a?(Array) && (data.select {|o| !(o.is_a?(Hash) && o[:Type] == :Page) } ).empty?
				pages_to_add = data
			elsif data.is_a?(Hash) && data[:Type] == :Page
				pages_to_add = [data]
			else
				warn "Shouldn't add objects to the file unless they are PDF objects or PDF pages (an Array or a single PDF page)."
				return false # return false, which will also stop any chaining.
			end
			catalog = rebuild_catalog
			pages_array = catalog[:Pages][:referenced_object][:Kids]
			page_count = pages_array.length
			if location < 0 && (page_count + location < 0 )
				location = 0
			elsif location > 0 && (location > page_count)
				location = page_count
			end
			pages_array.insert location, pages_to_add
			pages_array.flatten!
			self
		end

		# removes a PDF page from the file and the catalog
		#
		# returns the removed page.
		#
		# returns nil if failed or if out of bounds.
		#
		# page_index:: the page's index in the zero (0) based page array. negative numbers represent a count backwards (-1 being the end of the page array and 0 being the begining).
		def remove(page_index)
			catalog = rebuild_catalog
			pages_array = catalog[:Pages][:referenced_object][:Kids]
			removed_page = pages_array.delete_at page_index
			catalog[:Pages][:referenced_object][:Count] = pages_array.length
			removed_page
		end


		# add page numbers to the PDF
		#
		# For unicode text, a unicode font(s) must first be registered. the registered font(s) must supply the
		# subset of characters used in the text. UNICODE IS AN ISSUE WITH THE PDF FORMAT - USE CAUSION.
		#
		# options:: a Hash of options setting the behavior and format of the page numbers:
		# - :number_format a string representing the format for page number. defaults to ' - %s - ' (allows for letter numbering as well, such as "a", "b"...).
		# - :location an Array containing the location for the page numbers, can be :top, :buttom, :top_left, :top_right, :bottom_left, :bottom_right or :center (:center == full page). defaults to [:top, :buttom].
		# - :start_at a Fixnum that sets the number for first page number. also accepts a letter ("a") for letter numbering. defaults to 1.
		# - :margin_from_height a number (PDF points) for the top and buttom margins. defaults to 45.
		# - :margin_from_side a number (PDF points) for the left and right margins. defaults to 15.
		# - :page_range a range of pages to be numbered (i.e. (2..-1) ) defaults to all the pages (nil). Remember to set the :start_at to the correct value.
		# the options Hash can also take all the options for {Page_Methods#textbox}.
		# defaults to font: :Helvetica, font_size: 12 and no box (:border_width => 0, :box_color => nil).
		def number_pages(options = {})
			opt = {
				number_format: ' - %s - ',
				start_at: 1,
				font: :Helvetica,
				margin_from_height: 45,
				margin_from_side: 15
			}
			opt.update options
			opt[:location] ||= opt[:number_location] ||= opt[:stamp_location] ||= [:top, :bottom]
			opt[:location] = [opt[:location]] unless opt[:location].is_a? (Array)

			page_number = opt[:start_at]
			format_repeater = opt[:number_format].count('%')
			just_center = [:center]
			small_font_size = opt[:font_size] || 12

			(opt[:page_range] ? pages[opt[:page_range]] : pages).each do |page|
				# Get page dimensions
				mediabox = page[:CropBox] || page[:MediaBox] || [0, 0, 595.3, 841.9]
				# set stamp text
				text = opt[:number_format] % (Array.new(format_repeater) {page_number})
				if opt[:location].include? :center
					add_opt = {}
					if opt[:margin_from_height] && !opt[:height] && !opt[:y]
						add_opt[:height] = mediabox[3] - mediabox[1] - (2*opt[:margin_from_height].to_f)
						add_opt[:y] = opt[:margin_from_height]
					end
					if opt[:margin_from_side] && !opt[:width] && !opt[:x]
						add_opt[:width] = mediabox[2] - mediabox[0] - (2*opt[:margin_from_side].to_f)
						add_opt[:x] = opt[:margin_from_side]
					end
					page.textbox text, opt.merge(add_opt)
				end
				unless opt[:location] == just_center
					add_opt = { font_size: small_font_size }.merge(opt)
					# text = opt[:number_format] % page_number
					# compute locations for text boxes
					text_dimantions = page.dimensions_of( text, opt[:font], small_font_size )
					box_width = text_dimantions[0] * 1.2
					box_height = text_dimantions[1] * 2
					add_opt[:width] ||= box_width
					add_opt[:height] ||= box_height
					from_height = add_opt[:margin_from_height]
					from_side = add_opt[:margin_from_side]
					page_width = mediabox[2]
					page_height = mediabox[3]
					center_position = (page_width - box_width)/2
					left_position = from_side
					right_position = page_width - from_side - box_width
					top_position = page_height - from_height
					bottom_position = from_height + box_height
					if opt[:location].include? :top
						 page.textbox text, {x: center_position, y: top_position }.merge(add_opt)
					end
					if opt[:location].include? :bottom
						 page.textbox text, {x: center_position, y: bottom_position }.merge(add_opt)
					end
					if opt[:location].include? :top_left
						 page.textbox text, {x: left_position, y: top_position, font_size: small_font_size }.merge(add_opt)
					end
					if opt[:location].include? :bottom_left
						 page.textbox text, {x: left_position, y: bottom_position, font_size: small_font_size }.merge(add_opt)
					end
					if opt[:location].include? :top_right
						 page.textbox text, {x: right_position, y: top_position, font_size: small_font_size }.merge(add_opt)
					end
					if opt[:location].include? :bottom_right
						 page.textbox text, {x: right_position, y: bottom_position, font_size: small_font_size }.merge(add_opt)
					end
				end
				page_number = page_number.succ
			end

		end
		# This method stamps all (or some) of the pages is the PDF with the requested stamp.
		#
		# The method accept:
		# stamp:: either a String or a PDF page. If this is a String, you can add formating to add page numbering (i.e. "page number %i"). otherwise remember to escape any percent ('%') sign (i.e. "page \%number not shown\%").
		# options:: an options Hash.
		#
		# If the stamp is a PDF page, only :page_range and :underlay (to reverse-stamp) are valid options.
		#
		# If the stamp is a String, than all the options used by {#number_pages} or {Page_Methods#textbox} can be used.
		#
		# The default :location option is :center = meaning the stamp will be stamped all across the page unless the :x, :y, :width or :height options are specified.
		def stamp_pages stamp, options = {}
			case stamp
			when String
				options[:location] ||= [:center]
				number_pages({number_format: stamp}.merge(options))
			when Page_Methods
				# stamp = stamp.copy(true) 
				if options[:underlay]
					(options[:page_range] ? pages[options[:page_range]] : pages).each {|p| p >> stamp}
				else
					(options[:page_range] ? pages[options[:page_range]] : pages).each {|p| p << stamp}
				end
			else
				raise TypeError, "expecting a String or a PDF page as the stamp."
			end
		end

	end

end

