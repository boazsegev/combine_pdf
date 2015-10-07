# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################






module CombinePDF


	class PDF

		protected

		include Renderer

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
				# first if statement is actually a workaround for a bug in Acrobat Reader, regarding duplicate pages.
				if object[:is_reference_only] && object[:referenced_object] && object[:referenced_object].is_a?(Hash) && object[:referenced_object][:Type] == :Page
					if @objects.find_index object[:referenced_object]
						@objects << (object[:referenced_object] = object[:referenced_object].dup)
					else
						@objects << object[:referenced_object]
					end
				elsif object[:is_reference_only] && object[:referenced_object]
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
						# the object wasn't found - add it to the @objects array
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
			catalog_object[:ViewerPreferences] = @viewer_preferences unless @viewer_preferences.empty?

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
			@objects << @info
			add_referenced @info
			@objects << catalog
			add_referenced catalog
			catalog
		end

		def get_existing_catalogs
			(@objects.select {|obj| obj.is_a?(Hash) && obj[:Type] == :Catalog}) || (@objects.select {|obj| obj.is_a?(Hash) && obj[:Type] == :Page})
		end



		# end
		# @private
		def renumber_object_ids(start = nil)
			@set_start_id = start || @set_start_id
			start = @set_start_id
			history = {}
			@objects.each do |obj|
				obj[:indirect_reference_id] = start
				start += 1
			end
		end
		def remove_old_ids
			@objects.each {|obj| obj.delete(:indirect_reference_id); obj.delete(:indirect_generation_number)}
		end

	end
end

