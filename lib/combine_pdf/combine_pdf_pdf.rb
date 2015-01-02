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
	#   pdf << CombinePDF.new("file1.pdf") # one way to combine, very fast.
	#   pdf << CombinePDF.new("file2.pdf")
	#   pdf.save "combined.pdf"
	# or even a one liner:
	#   (CombinePDF.new("file1.pdf") << CombinePDF.new("file2.pdf") << CombinePDF.new("file3.pdf")).save("combined.pdf")
	# you can also add just odd or even pages:
	#   pdf = CombinePDF.new
	#   i = 0
	#   CombinePDF.new("file.pdf").pages.each do |page|
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
	class PDF
		# the objects attribute is an Array containing all the PDF sub-objects for te class.
		attr_reader :objects
		# the info attribute is a Hash that sets the Info data for the PDF.
		# use, for example:
		#   pdf.info[:Title] = "title"
		attr_reader :info
		# gets/sets the string output format (PDF files store strings in to type of formats).
		#
		# Accepts:
		# - :literal
		# - :hex
		attr_accessor :string_output
		# set/get the PDF version of the file (1.1-1.7) - shuold be type Float.
		attr_accessor :version
		def initialize (*args)
			# default before setting
			@objects = []
			@version = 0 
			@info = {}
			if args[0].is_a? PDFParser
				@objects = args[0].parse
				# connecting references with original objects
				serialize_objects_and_references
				# make sure there is only one Catalog (the latest Catalog)
				if args[0].root_object[:Root]
					@objects.delete_if {|obj| obj[:Type] == :Catalog}
					@objects << args[0].root_object[:Root]
				else
					last_calalog = (@objects.select {|obj| obj[:Type] == :Catalog}).last
					unless last_calalog.nil?
					@objects.delete_if {|obj| obj[:Type] == :Catalog}
					@objects << last_calalog
					end
				end
				@version = args[0].version if args[0].version.is_a? Float
				@info = args[0].info_object || {}
			elsif args[0].is_a? Array
				# object initialization
				@objects = args[0]
				@version = args[1] if args[1].is_a? Float
				# connecting references with original objects
				serialize_objects_and_references
			elsif args[0].is_a? Hash
				@objects = args
				# connecting references with original objects
				serialize_objects_and_references
			end
			# general globals
			@string_output = :literal
			@set_start_id = 1
			@info[:Producer] = "Ruby CombinePDF Library by Boaz Segev"
			@info.delete :CreationDate
			@info.delete :ModDate
		end

		# Formats the data to PDF formats and returns a binary string that represents the PDF file content.
		#
		# This method is used by the save(file_name) method to save the content to a file.
		#
		# use this to export the PDF file without saving to disk (such as sending through HTTP ect').
		def to_pdf
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
			out << "%PDF-#{@version.to_s}\n%\x00\x00\x00\x00".force_encoding(Encoding::ASCII_8BIT)

			#collect objects and set xref table locations
			loc = 0
			out.each {|line| loc += line.bytesize + 1}
			@objects.each do |o|
				indirect_object_count += 1
				xref << loc
				out << PDFOperations._object_to_pdf(o)
				loc += out.last.length + 1
			end
			xref_location = 0
			out.each { |line| xref_location += line.bytesize + 1}
			out << "xref\n\r0 #{(indirect_object_count).to_s}\n\r0000000000 65535 f \n\r"
			xref.each {|offset| out << ( out.pop + ("%010d 00000 n \n\r" % offset) ) }
			out << out.pop + "trailer"
			out << "<<\n/Root #{false || "#{catalog[:indirect_reference_id]} #{catalog[:indirect_generation_number]} R"}"
			out << "/Size #{indirect_object_count.to_s}"
			if @info.is_a?(Hash)
				PRIVATE_HASH_KEYS.each {|key| @info.delete key} # make sure the dictionary is rendered inline, without stream
				out << "/Info #{PDFOperations._object_to_pdf @info}"
			end
			out << ">>\nstartxref\n#{xref_location.to_s}\n%%EOF"
			# when finished, remove the numbering system and keep only pointers
			PDFOperations.remove_old_ids @objects
			# output the pdf stream
			out.join("\n").force_encoding(Encoding::ASCII_8BIT)
		end

		# Save the PDF to file.
		# 
		# file_name:: is a string or path object for the output.
		#
		# <b>Notice!</b> if the file exists, it <b>WILL</b> be overwritten.
		def save(file_name)
			IO.binwrite file_name, to_pdf
		end
		# this method returns all the pages cataloged in the catalog.
		#
		# if no catalog is passed, it seeks the existing catalog(s) and searches
		# for any registered Page objects.
		#
		# This method also adds the << operator to each page instance, so that content can be
		# injected to the pages, as described above.
		#
		# if the secure_injection is false, then the << operator will not alter the any of the information added to the page.
		# this might cause conflicts in the added content, but is available for situations in which
		# the content added is compressed using unsupported filters or options.
		#
		# the default is for the << operator to attempt a secure copy, by attempting to rename the content references and avoiding conflicts.
		# because not all PDF files are created equal (some might have formating errors or variations),
		# it is imposiible to learn if the attempt was successful.
		#
		# (page objects are Hash class objects. the << operator is added to the specific instances without changing the class)
		#
		# catalogs:: a catalog, or an Array of catalog objects. defaults to the existing catalog.
		# secure_injection:: a boolean (true / false) controling the behavior of the << operator.
		def pages(catalogs = nil, secure_injection = true, inheritance_hash = {})
			page_list = []
			if catalogs == nil
				catalogs = @objects.select {|obj| obj.is_a?(Hash) && obj[:Type] == :Catalog}
				catalogs ||= []
			end
			case 
			when catalogs.is_a?(Array)
				catalogs.each {|c| page_list.push *( pages(c, secure_injection, inheritance_hash ) ) unless c.nil?}
			when catalogs.is_a?(Hash)
				if catalogs[:is_reference_only]
					# not applicable any more... | catalogs[:referenced_object] = PDFOperations.get_refernced_object(@objects, catalogs) # for some reson, the code was: pages(PDFOperations.get_refernced_object(@objects, catalogs), secure_injection, inheritance_hash) unless catalogs[:referenced_object]
					if catalogs[:referenced_object]
						page_list.push *( pages(catalogs[:referenced_object], secure_injection, inheritance_hash) )
					else
						warn "couldn't follow reference!!! #{catalogs} not found!"
					end
				else
					unless catalogs[:Type] == :Page
						# set inheritance, when applicable
						inheritance_hash[:MediaBox] = catalogs[:MediaBox] if catalogs[:MediaBox]
						inheritance_hash[:CropBox] = catalogs[:CropBox] if catalogs[:CropBox]
						(inheritance_hash[:Resources] ||= {}).update( (catalogs[:Resources][:referenced_object] || catalogs[:Resources]), &self.class.method(:hash_update_proc_for_new) ) if catalogs[:Resources]
						(inheritance_hash[:ColorSpace] ||= {}).update( (catalogs[:ColorSpace][:referenced_object] || catalogs[:ColorSpace]), &self.class.method(:hash_update_proc_for_new) ) if catalogs[:ColorSpace]
					end

					case catalogs[:Type]
					when :Page
						holder = self
						if secure_injection
							catalogs.define_singleton_method("<<".to_sym) do |obj|
								obj = PDFOperations.copy_and_secure_for_injection obj
								PDFOperations.inject_to_page self, obj
								holder.add_referenced self # add new referenced objects
								self
							end
						else
							catalogs.define_singleton_method("<<".to_sym) do |obj|
								obj = PDFOperations.create_deep_copy obj
								PDFOperations.inject_to_page self, obj
								holder.add_referenced self # add new referenced objects
								self
							end
						end

						# inheritance 
						catalogs[:MediaBox] ||= inheritance_hash[:MediaBox] if inheritance_hash[:MediaBox]
						catalogs[:CropBox] ||= inheritance_hash[:CropBox] if inheritance_hash[:CropBox]
						(catalogs[:Resources] ||= {}).update( inheritance_hash[:Resources], &( self.class.method(:hash_update_proc_for_old) ) ) if inheritance_hash[:Resources]
						(catalogs[:ColorSpace] ||= {}).update( inheritance_hash[:ColorSpace], &( self.class.method(:hash_update_proc_for_old) ) ) if inheritance_hash[:ColorSpace]


						# avoide references on MediaBox and CropBox
						catalogs[:MediaBox] = catalogs[:MediaBox][:referenced_object][:indirect_without_dictionary] if catalogs[:MediaBox].is_a?(Hash) && catalogs[:MediaBox][:referenced_object].is_a?(Hash) && catalogs[:MediaBox][:referenced_object][:indirect_without_dictionary]
						catalogs[:CropBox] = catalogs[:CropBox][:referenced_object][:indirect_without_dictionary] if catalogs[:CropBox].is_a?(Hash) && catalogs[:CropBox][:referenced_object].is_a?(Hash) && catalogs[:CropBox][:referenced_object][:indirect_without_dictionary]

						page_list << catalogs
					when :Pages
						page_list.push *(pages(catalogs[:Kids], secure_injection, inheritance_hash.dup )) unless catalogs[:Kids].nil?
					when :Catalog
						page_list.push *(pages(catalogs[:Pages], secure_injection, inheritance_hash.dup )) unless catalogs[:Pages].nil?
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
			#########
			## how should we add data to PDF?
			## and how to handles imported pages?
			if data.is_a?(PDF)
		 		@version = [@version, data.version].max
		 		@objects.push(*data.objects)
				# rebuild_catalog
				return self
			end
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
			self
		end

		# add PDF pages (or PDF files) into a specific location.
		#
		# returns the new pages Array
		#
		# location:: the location for the added page(s). Could be any number. negative numbers represent a count backwards (-1 being the end of the page array and 0 being the begining). if the location is beyond bounds, the pages will be added to the end of the PDF object (or at the begining, if the out of bounds was a negative number).
		# data:: a PDF page, a PDF file (CombinePDF.new "filname.pdf") or an array of pages (CombinePDF.new("filname.pdf").pages[0..3]).
		def insert(location, data)
			pages_to_add = nil
			if data.is_a? PDF
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
			pages_array
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
		# - :number_location an Array containing the location for the page numbers, can be :top, :buttom, :top_left, :top_right, :bottom_left, :bottom_right. defaults to [:top, :buttom].
		# - :start_at a Fixnum that sets the number for first page number. also accepts a letter ("a") for letter numbering. defaults to 1.
		# - :margin_from_height a number (PDF points) for the top and buttom margins. defaults to 45.
		# - :margin_from_side a number (PDF points) for the left and right margins. defaults to 15.
		# the options Hash can also take all the options for PDFWriter.textbox.
		# defaults to font: :Helvetica, font_size: 12 and no box (:border_width => 0, :box_color => nil).
		def number_pages(options = {})
			opt = {
				number_format: ' - %s - ',
				number_location: [:top, :bottom],
				start_at: 1,
				font_size: 12,
				font: :Helvetica,
				margin_from_height: 45,
				margin_from_side: 15
			}
			opt.update options
			page_number = opt[:start_at]
			pages.each do |page|
				# create a "stamp" PDF page with the same size as the target page
				mediabox = page[:CropBox] || page[:MediaBox] || [0, 0, 595.3, 841.9]
				stamp = PDFWriter.new mediabox
				# set stamp text
				text = opt[:number_format] % page_number
				# compute locations for text boxes
				text_dimantions = stamp.dimensions_of( text, opt[:font], opt[:font_size] )
				box_width = text_dimantions[0] * 1.2
				box_height = text_dimantions[1] * 2
				opt[:width] = box_width
				opt[:height] = box_height
				from_height = 45
				from_side = 15
				page_width = mediabox[2]
				page_height = mediabox[3]
				center_position = (page_width - box_width)/2
				left_position = from_side
				right_position = page_width - from_side - box_width
				top_position = page_height - from_height
				buttom_position = from_height + box_height
				x = center_position
				y = top_position
				if opt[:number_location].include? :top
					 stamp.textbox text, {x: x, y: y }.merge(opt)
				end
				y = buttom_position #bottom position
				if opt[:number_location].include? :bottom
					 stamp.textbox text, {x: x, y: y }.merge(opt)
				end
				y = top_position #top position
				x = left_position # left posotion
				if opt[:number_location].include? :top_left
					 stamp.textbox text, {x: x, y: y }.merge(opt)
				end
				y = buttom_position #bottom position
				if opt[:number_location].include? :bottom_left
					 stamp.textbox text, {x: x, y: y }.merge(opt)
				end
				x = right_position # right posotion
				y = top_position #top position
				if opt[:number_location].include? :top_right
					 stamp.textbox text, {x: x, y: y }.merge(opt)
				end
				y = buttom_position #bottom position
				if opt[:number_location].include? :bottom_right
					 stamp.textbox text, {x: x, y: y }.merge(opt)
				end
				page << stamp
				page_number = page_number.succ
			end
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
	end

	#:nodoc: all


	class PDF
		# @private
		# Some PDF objects contain references to other PDF objects.
		#
		# this function adds the references contained in "object", but DOESN'T add the object itself.
		#
		# this is used for internal operations, such as injectng data using the << operator.
		def add_referenced(object)
			# add references but not root
			case 
			when object.is_a?(Array)
				object.each {|it| add_referenced(it)}
				return true
			when object.is_a?(Hash)
				if object[:is_reference_only] && object[:referenced_object]
					found_at = @objects.find_index object[:referenced_object]
					if found_at
						#if the objects are equal, they might still be different objects!
						# so, we need to make sure they are the same object for the pointers to effect id numbering
						# and formatting operations.
						object[:referenced_object] = @objects[found_at]
						# stop this path, there is no need to run over the Hash's keys and values
						return true
					else
						# @objects.include? object[:referenced_object] is bound to be false
						#the object wasn't found - add it to the @objects array
						@objects << object[:referenced_object]
					end

				end
				object.each do |k, v|
					add_referenced(v) unless k == :Parent 
				end
			else
				return false
			end
			true
		end
		# @private
		# run block of code on evey PDF object (PDF objects are class Hash)
		def each_object(&block)
			PDFOperations._each_object(@objects, &block)
		end

		protected

		# @private
		# this method reviews a Hash an updates it by merging Hash data,
		# preffering the old over the new.
		def self.hash_update_proc_for_old key, old_data, new_data
			if old_data.is_a? Hash
				old_data.merge( new_data, &self.method(:hash_update_proc_for_old) )
			else
				old_data
			end
		end
		# @private
		# this method reviews a Hash an updates it by merging Hash data,
		# preffering the new over the old.
		def self.hash_update_proc_for_new key, old_data, new_data
			if old_data.is_a? Hash
				old_data.merge( new_data, &self.method(:hash_update_proc_for_new) )
			else
				new_data
			end
		end

		# @private
		# this function returns all the Page objects - regardless of order and even if not cataloged
		# could be used for finding "lost" pages... but actually rather useless. 
		def all_pages
			#########
			## Only return the page item, but make sure all references are connected so that
			## referenced items and be reached through the connections.
			[].tap {|out|  each_object {|obj| out << obj  if obj.is_a?(Hash) && obj[:Type] == :Page }  }
		end
		# @private
		def serialize_objects_and_references(object = nil)
			# # Version 3.5 injects indirect objects if they arn't dictionaries.
			# # benchmark 1000.times was 3.568246 sec for pdf = CombinePDF.new "/Users/2Be/Desktop/מוצגים/20121002\ הודעת\ הערעור.pdf" }
			# # puts Benchmark.measure { 1000.times {pdf.serialize_objects_and_references} }
			# # ######### Intreduces a BUG with catalogging pages... why? I don't know... mybey doesn't catch all.
			# each_object do |obj|
			# 	obj.each do |k, v|
			# 		if v.is_a?(Hash) && v[:is_reference_only]
			# 			v[:referenced_object] = PDFOperations.get_refernced_object @objects, v
			# 			raise "couldn't connect references" unless v[:referenced_object]
			# 			obj[k] = v[:referenced_object][:indirect_without_dictionary] if v[:referenced_object][:indirect_without_dictionary]
			# 		end
			# 	end
			# end

			# Version 4
			# benchmark 1000.times was 0.980651 sec for:
			# pdf = CombinePDF.new "/Users/2Be/Desktop/מוצגים/20121002\ הודעת\ הערעור.pdf"
			# puts Benchmark.measure { 1000.times {pdf.serialize_objects_and_references} }
			objects_reference_hash = {}
			@objects.each {|o| objects_reference_hash[ [o[:indirect_reference_id], o[:indirect_generation_number] ] ] = o }
			each_object do |obj|
				if obj[:is_reference_only]
					obj[:referenced_object] = objects_reference_hash[ [obj[:indirect_reference_id], obj[:indirect_generation_number] ]   ]
					warn "couldn't connect a reference!!! could be a null or removed (empty) object, Silent error!!!\n Object raising issue: #{obj.to_s}" unless obj[:referenced_object]
				end
			end

			# when finished, remove the old numbering system and keep only pointers
			PDFOperations.remove_old_ids @objects

			# # Version 3
			# # benchmark 1000.times was 3.568246 sec for pdf = CombinePDF.new "/Users/2Be/Desktop/מוצגים/20121002\ הודעת\ הערעור.pdf" }
			# # puts Benchmark.measure { 1000.times {pdf.serialize_objects_and_references} }
			# each_object do |obj|
			# 	if obj[:is_reference_only]
			# 		obj[:referenced_object] = PDFOperations.get_refernced_object @objects, obj
			# 		warn "couldn't connect a reference!!! could be a null object, Silent error!!!" unless obj[:referenced_object]
			# 	end
			# end

		end
		# @private
		def renumber_object_ids(start = nil)
			@set_start_id = start || @set_start_id
			start = @set_start_id
			history = {}
			all_indirect_object.each do |obj|
				obj[:indirect_reference_id] = start
				start += 1
			end
		end

		# @private
		def references(indirect_reference_id = nil, indirect_generation_number = nil)
			ref = {indirect_reference_id: indirect_reference_id, indirect_generation_number: indirect_generation_number}
			out = []
			each_object do |obj|
				if obj[:is_reference_only]
					if (indirect_reference_id == nil && indirect_generation_number == nil)
						out << obj 
					elsif compare_reference_values(ref, obj)
						out << obj 
					end
				end
			end
			out
		end
		# @private
		def all_indirect_object
			# [].tap {|out| @objects.each {|obj| out << obj if (obj.is_a?(Hash) && obj[:is_reference_only].nil?) } }
			@objects
		end
		# @private
		def sort_objects_by_id
			@objects.sort! do |a,b|
				if a.is_a?(Hash) && a[:indirect_reference_id] && a[:is_reference_only].nil? && b.is_a?(Hash) && b[:indirect_reference_id] && b[:is_reference_only].nil?
					return a[:indirect_reference_id] <=> b[:indirect_reference_id]
				end
				0
			end
		end

		# @private
		def rebuild_catalog(*with_pages)
			# # build page list v.1 Slow but WORKS
			# # Benchmark testing value: 26.708394
			# old_catalogs = @objects.select {|obj| obj.is_a?(Hash) && obj[:Type] == :Catalog}
			# old_catalogs ||= []
			# page_list = []
			# PDFOperations._each_object(old_catalogs,false) { |p| page_list << p if p.is_a?(Hash) && p[:Type] == :Page }

			# build page list v.2 faster, better, and works
			# Benchmark testing value: 0.215114
			page_list = pages

			# add pages to catalog, if requested
			page_list.push(*with_pages) unless with_pages.empty?

			# build new Pages object
			pages_object = {Type: :Pages, Count: page_list.length, Kids: page_list.map {|p| {referenced_object: p, is_reference_only: true} } }

			# build new Catalog object
			catalog_object = {Type: :Catalog, Pages: {referenced_object: pages_object, is_reference_only: true} }

			# point old Pages pointers to new Pages object
			## first point known pages objects - enough?
			pages.each {|p| p[:Parent] = { referenced_object: pages_object, is_reference_only: true} }
			## or should we, go over structure? (fails)
			# each_object {|obj| obj[:Parent][:referenced_object] = pages_object if obj.is_a?(Hash) && obj[:Parent].is_a?(Hash) && obj[:Parent][:referenced_object] && obj[:Parent][:referenced_object][:Type] == :Pages}

			# remove old catalog and pages objects
			@objects.reject! {|obj| obj.is_a?(Hash) && (obj[:Type] == :Catalog || obj[:Type] == :Pages) }

			# inject new catalog and pages objects
			@objects << pages_object
			@objects << catalog_object

			catalog_object
		end

		# @private
		# this is an alternative to the rebuild_catalog catalog method
		# this method is used by the to_pdf method, for streamlining the PDF output.
		# there is no point is calling the method before preparing the output.
		def rebuild_catalog_and_objects
			catalog = rebuild_catalog
			@objects = []
			@objects << catalog
			add_referenced catalog
			catalog
		end

		# @private
		# the function rerturns true if the reference belongs to the object
		def compare_reference_values(obj, ref)
			if obj[:referenced_object] && ref[:referenced_object]
				return (obj[:referenced_object][:indirect_reference_id] == ref[:referenced_object][:indirect_reference_id] && obj[:referenced_object][:indirect_generation_number] == ref[:referenced_object][:indirect_generation_number])
			elsif ref[:referenced_object]
				return (obj[:indirect_reference_id] == ref[:referenced_object][:indirect_reference_id] && obj[:indirect_generation_number] == ref[:referenced_object][:indirect_generation_number])
			elsif obj[:referenced_object]
				return (obj[:referenced_object][:indirect_reference_id] == ref[:indirect_reference_id] && obj[:referenced_object][:indirect_generation_number] == ref[:indirect_generation_number])
			else
				return (obj[:indirect_reference_id] == ref[:indirect_reference_id] && obj[:indirect_generation_number] == ref[:indirect_generation_number])
			end
		end


	end
end

