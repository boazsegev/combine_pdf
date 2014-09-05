# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################






module CombinePDF
	#######################################################
	# PDF class is the PDF object that can save itself to
	# a file and that can be used as a container for a full
	# PDF file data, including version etc'.
	#
	# PDF objects can be used to combine or to inject data.
	# == Combine
	# To combine PDF files (or data):
	#   pdf = CombinePDF.new
	#   pdf << CombinePDF.new "file1.pdf" # one way to combine, very fast.
	#   CombinePDF.new("file2.pdf").pages.each {|page| pdf << page} # different way to combine, slower.
	#   pdf.save "combined.pdf"
	# == Stamp / Watermark
	# To combine PDF files (or data), first create the stamp from a PDF file:
	#   stamp_pdf_file = CombinePDF.new "stamp_pdf_file.pdf"
	#   stamp_page = stamp_pdf_file.pages[0]
	# After the stamp was created, inject to PDF pages:
	#   pdf = CombinePDF.new "file1.pdf"
	#   pdf.pages.each {|page| page << stamp_page} # notice the << operator is on a page and not a PDF object.
	#######################################################
	class PDF
		# the objects attribute is an Array containing all the PDF sub-objects for te class.
		attr_reader :objects
		# the info attribute is a Hash that sets the Info data for the PDF.
		# use, for example:
		#   pdf.info[:Title] = "title"
		attr_reader :info
		# sets the string output format (PDF files store strings in to type of formats).
		#
		# Accepts:
		# - :literal
		# - :hex
		attr_accessor :string_output
		# A Float attrinute, setting and returning the PDF version of the file (1.1-1.7).
		attr_accessor :version
		def initialize (*args)
			# default before setting
			@objects = []
			@version = 0 
			@info = {}
			if args[0].is_a? PDFParser
				@objects = args[0].parse
				@version = args[0].version if args[0].version.is_a? Float
				@info = args[0].info_object || {}
			elsif args[0].is_a? Array
				# object initialization
				@objects = args[0]
				@version = args[1] if args[1].is_a? Float
			elsif args[0].is_a? Hash
				@objects = args
			end
			# connecting references with original objects
			serialize_objects_and_references
			# general globals
			@string_output = :literal
			@need_to_rebuild_resources = false
			@set_start_id = 1
			@info[:Producer] = "Ruby CombinePDF Library by Boaz Segev"
			@info.delete :CreationDate
			@info.delete :ModDate
			warn "finished to initialize PDF object."
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
			#rebuild resources if needed
			if @need_to_rebuild_resources
				rebuild_resources
			end
			catalog = rebuild_catalog_and_objects #rebuild_catalog

			warn "Formatting PDF output"

			out = []
			xref = []
			indirect_object_count = 1 #the first object is the null object
			#write head (version and binanry-code)
			out << "%PDF-#{@version.to_s}\n%\x00\x00\x00\x00".force_encoding(Encoding::ASCII_8BIT)

			#collect objects and set xref table locations
			loc = 0
			out.each {|line| loc += line.bytes.length + 1}
			@objects.each do |o|
				indirect_object_count += 1
				xref << loc
				out << PDFOperations._object_to_pdf(o)
				loc += out.last.length + 1
			end
			warn "Building XREF"
			xref_location = 0
			out.each { |line| xref_location += line.bytes.length + 1}
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
			out.join("\n").force_encoding(Encoding::ASCII_8BIT)
		end

		# Seve the PDF to file.
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
		# because of not all PDF files are created equal (some might have formating errors or differences), it is imposiible to learn if the attempt wa successful.
		#
		# (page objects are Hash class objects. the << operator is added to the specific instances without changing the class)
		#
		# catalogs:: a catalog, or an Array of catalog objects. defaults to the existing catalog.
		# secure_injection:: a boolean (true / false) controling the behavior of the << operator.
		def pages(catalogs = nil, secure_injection = true)
			page_list = []
			if catalogs == nil
				catalogs = @objects.select {|obj| obj.is_a?(Hash) && obj[:Type] == :Catalog}
				catalogs ||= []
			end
			case 
			when catalogs.is_a?(Array)
				catalogs.each {|c| page_list.push *(pages(c)) unless c.nil?}
			when catalogs.is_a?(Hash)
				if catalogs[:is_reference_only]
					catalogs[:referenced_object] = pages(PDFOperations.get_refernced_object @objects, catalogs) unless catalogs[:referenced_object]
					if catalogs[:referenced_object]
						page_list.push *( pages(catalogs[:referenced_object]) )
					else
						warn "couldn't follow reference!!! #{catalogs} not found!"
					end
				else
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

		# this function adds pages or CombinePDF objects at the end of the file (merge)
		# for example:
		#
		#   pdf = CombinePDF.new "first_file.pdf"
		#
		#   pdf << CombinePDF.new "second_file.pdf"
		#
		#   pdf.save "both_files_merged.pdf"
		# @params obj is Hash, PDF or Array of parsed PDF data.
		def << (obj)
			#########
			## how should we add data to PDF?
			## and how to handles imported pages?
			case
			when (obj.is_a?(PDF))
		 		@version = [@version, obj.version].max

		 		obj.renumber_object_ids @set_start_id + @objects.length

		 		@objects.push(*obj.objects)
				# rebuild_catalog
				@need_to_rebuild_resources = true
			when (obj.is_a?(Hash) && obj[:Type] == :Page), (obj.is_a?(Array) && (obj.reject {|i| i.is_a?(Hash) && i[:Type] == :Page}).empty?)
			 	# set obj paramater to array if it's only one page
			 	obj = [obj] if obj.is_a?(Hash)
				# add page(s) to objects
				@objects.push(*obj)
				# add page dependencies to objects
				add_referenced(obj)
				# add page(s) to Catalog(s)
				rebuild_catalog obj
				@need_to_rebuild_resources = true
			when (obj.is_a?(Hash) && obj[:indirect_reference_id] && obj[:referenced_object].nil?)
				#only let top level indirect objects into the PDF tree.
				@objects << obj
				@need_to_rebuild_resources = true
			else
				warn "Shouldn't add objects to the file if they are not top-level indirect PDF objects."
				retrun false # return false, which will also stop any chaining.
			end
			return self #return self object for injection chaining (pdf << page << page << page)
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
		# get the author value for the pdf
		# The author is stored in the information dictionary and isn't required
		def author
			return @info[:Author]
		end
		# set the author for the pdf
		# The author is stored in the information dictionary and isn't required
		# new_title:: a string that is the new author value.
		def author=(new_author = nil)
			@info[:Author] = new_author
		end
	end
	class PDF #:nodoc: all
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
			when object.is_a?(Hash)
				if object[:is_reference_only] && object[:referenced_object]
					unless @objects.include? object[:referenced_object]
						@objects << object[:referenced_object]
						object[:referenced_object].each do |k, v|
							add_referenced(v) unless k == :Parent
						end						
					end
				else
					object.each do |k, v|
						add_referenced(v) unless k == :Parent 
					end
				end
			end
		end
		# @private
		# run block of code on evey object (Hash)
		def each_object(&block)
			PDFOperations._each_object(@objects, &block)
		end
		protected
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
			warn "connecting objects with their references (serialize_objects_and_references)."

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
					warn "couldn't connect a reference!!! could be a null object, Silent error!!!" unless obj[:referenced_object]
				end
			end

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
			warn "Resetting Object Reference IDs"
			@set_start_id ||= start
			start = @set_start_id
			history = {}
			all_indirect_object.each do |obj|
				obj[:indirect_reference_id] = start
				start += 1
			end
			warn "Finished serializing IDs"
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
			[].tap {|out| @objects.each {|obj| out << obj if (obj.is_a?(Hash) && obj[:is_reference_only].nil?) } }
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
			##########################
			## Test-Run - How is that done?
			warn "Re-Building Catalog"

			# # build page list v.1 Slow but WORKS
			# # Benchmark testing value: 26.708394
			# old_catalogs = @objects.select {|obj| obj.is_a?(Hash) && obj[:Type] == :Catalog}
			# old_catalogs ||= []
			# page_list = []
			# PDFOperations._each_object(old_catalogs,false) { |p| page_list << p if p.is_a?(Hash) && p[:Type] == :Page }

			# build page list v.2
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
			renumber_object_ids
			catalog
		end

		# @private
		# disabled, don't use. simpley returns true.
		def rebuild_resources

			warn "Resources re-building disabled as it isn't worth the price in peformance as of yet."

			return true

			warn "Re-Building Resources"
			@need_to_rebuild_resources = false
			# what are resources?
			# anything at the top level of the file exept catalogs, page lists (Pages) and pages...
			not_resources = [:Catalog, :Pages, :Page]
			# get old resources list
			old_resources = @objects.select {|obj| obj.is_a?(Hash) && !not_resources.include?(obj[:Type])}
			# collect all unique resources while ignoring double values and resetting references
			# also ignore inner values (canot use PRIVATE_HASH_KEYS because of stream and other issues)
			ignore_keys = [:indirect_reference_id, :indirect_generation_number, :is_reference_only, :referenced_object]
			new_resources = []
			all_references = references
			old_resources.each do |old_r|
				add = true
				new_resources.each do |new_r|
					# ## v.1.0 - slower
					# if (old_r.reject {|k,v| ignore_keys.include?(k) }) == (new_r.reject {|k,v| ignore_keys.include?(k)})
					# 	all_references.each {|ref| ref[:referenced_object] = new_r if ref[:referenced_object].object_id == old_r.object_id }  # fails, but doesn't assume all references are connected: compare_reference_values(old_r, ref) }
					# 	add = false
					# end
					## v.1.1 - faster, doesn't build two hashes (but iterates one)
					if ( [].tap {|out| old_r.each {|k,v| out << true unless ((!ignore_keys.include?(k)) && new_r[k] == v) } } .empty?)
						all_references.each {|ref| ref[:referenced_object] = new_r if ref[:referenced_object].object_id == old_r.object_id }  # fails, but doesn't assume all references are connected: compare_reference_values(old_r, ref) }
						add = false
					end
				end
				new_resources << old_r if add
			end
			# remove old resources
			@objects.reject! {|obj| old_resources.include?(obj)}
			# insert new resources
			@objects.push *new_resources
			# rebuild stream lengths?
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

