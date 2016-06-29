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

    RECORSIVE_PROTECTION = { Parent: true, First: true, Next: true, Prev: true, Last: true}.freeze

    # @private
    # Some PDF objects contain references to other PDF objects.
    #
    # this function adds the references contained in "object", but DOESN'T add the object itself.
    #
    # this is used for internal operations, such as injectng data using the << operator.
    def add_referenced
      # add references but not root
      should_resolve = @objects.dup
      dup_pages = nil
      resolved = [].to_set
      reviewer = [].to_set
      until should_resolve.empty?
        obj = should_resolve.pop
        if(obj.is_a?(Hash))
          next if(resolved.include? obj.object_id)
          resolved << obj.object_id
          if obj[:referenced_object]
            tmp = @objects.find_index(obj[:referenced_object])
            if(tmp)
              tmp = @objects[tmp]
              obj[:referenced_object] = tmp
            else
              tmp = obj[:referenced_object]
              should_resolve << tmp
              @objects << tmp
            end
          else
            obj.keys.each {|k| should_resolve << obj[k] unless RECORSIVE_PROTECTION[k] || resolved.include?(obj[k].object_id) || !obj[k].is_a?(Enumerable)}
          end
        elsif (obj.is_a?(Array))
          next if(resolved.include? obj.object_id)
          resolved << obj.object_id
          should_resolve.concat obj
        end
      end
      resolved.clear
    end


    # # @private
    # # Some PDF objects contain references to other PDF objects.
    # #
    # # this function adds the references contained in "object", but DOESN'T add the object itself.
    # #
    # # this is used for internal operations, such as injectng data using the << operator.
    # def add_referenced(object, dup_pages = true)
    #   # add references but not root
    #   if object.is_a?(Array)
    #     object.each { |it| add_referenced(it, dup_pages) }
    #     return true
    #   elsif object.is_a?(Hash)
    #     # first if statement is actually a workaround for a bug in Acrobat Reader, regarding duplicate pages.
    #     if dup_pages && object[:is_reference_only] && object[:referenced_object] && object[:referenced_object].is_a?(Hash) && object[:referenced_object][:Type] == :Page
    #       if @objects.find_index object[:referenced_object]
    #         @objects << (object[:referenced_object] = object[:referenced_object].dup)
    #       else
    #         @objects << object[:referenced_object]
    #       end
    #     elsif object[:is_reference_only] && object[:referenced_object]
    #       found_at = @objects.find_index object[:referenced_object]
    #       if found_at
    #         # if the objects are equal, they might still be different objects!
    #         # so, we need to make sure they are the same object for the pointers to effect id numbering
    #         # and formatting operations.
    #         object[:referenced_object] = @objects[found_at]
    #         # stop this path, there is no need to run over the Hash's keys and values
    #         return true
    #       else
    #         # stop if page propegation is false
    #         return true if !dup_pages && object[:referenced_object][:Type] == :Page
    #         # @objects.include? object[:referenced_object] is bound to be false
    #         # the object wasn't found - add it to the @objects array
    #         @objects << object[:referenced_object]
    #       end
    #
    #     end
    #     object.each do |k, v|
    #         add_referenced(v, dup_pages) unless RECORSIVE_PROTECTION[k]
    #     end
    #   else
    #     return false
    #   end
    #   true
    # end

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
      page_list.concat(with_pages) unless with_pages.empty?

      # build new Pages object
      pages_object = { Type: :Pages, Count: page_list.length, Kids: page_list.map { |p| { referenced_object: p, is_reference_only: true } } }

      # rebuild/rename the names dictionary
      rebuild_names
      # build new Catalog object
      catalog_object = { Type: :Catalog,
												 Pages: { referenced_object: pages_object, is_reference_only: true },
												 Names: { referenced_object: @names, is_reference_only: true },
											   Outlines: { referenced_object: @outlines, is_reference_only: true } }
      catalog_object[:ViewerPreferences] = @viewer_preferences unless @viewer_preferences.empty?

      # rebuild/rename the forms dictionary
      if @forms_data.nil? || @forms_data.empty?
        @forms_data = nil
      else
        @forms_data = { referenced_object: (@forms_data[:referenced_object] || @forms_data), is_reference_only: true }
        catalog_object[:AcroForm] = @forms_data
      end

      # point old Pages pointers to new Pages object
      ## first point known pages objects - enough?
      pages.each { |p| p[:Parent] = { referenced_object: pages_object, is_reference_only: true } }
      ## or should we, go over structure? (fails)
      # each_object {|obj| obj[:Parent][:referenced_object] = pages_object if obj.is_a?(Hash) && obj[:Parent].is_a?(Hash) && obj[:Parent][:referenced_object] && obj[:Parent][:referenced_object][:Type] == :Pages}

      # remove old catalog and pages objects
      @objects.reject! { |obj| obj.is_a?(Hash) && (obj[:Type] == :Catalog || obj[:Type] == :Pages) }

      # inject new catalog and pages objects
      @objects << pages_object
      @objects << catalog_object

      catalog_object
    end

    def names_object
      @names
    end
		def outlines_object
			@outlines
		end
    # def forms_data
    # 	@forms_data
    # end

    # @private
    # this is an alternative to the rebuild_catalog catalog method
    # this method is used by the to_pdf method, for streamlining the PDF output.
    # there is no point is calling the method before preparing the output.
    def rebuild_catalog_and_objects
      catalog = rebuild_catalog
      @objects.clear
      @objects << @info
      @objects << catalog
      catalog[:Pages][:referenced_object][:Kids].each do |page|
        tmp = page[:referenced_object]
        if(@objects.include? tmp)
          tmp = page[:referenced_object] = tmp.dup
        end
        @objects << tmp
      end
      add_referenced
      # @objects << @info
      # add_referenced @info
      # add_referenced catalog
      # add_referenced catalog[:Pages]
      # add_referenced catalog[:Names], false
  ##### add_referenced catalog[:Outlines], false
      # add_referenced catalog[:AcroForm], false
      catalog
    end

    def get_existing_catalogs
      (@objects.select { |obj| obj.is_a?(Hash) && obj[:Type] == :Catalog }) || (@objects.select { |obj| obj.is_a?(Hash) && obj[:Type] == :Page })
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
      @objects.each { |obj| obj.delete(:indirect_reference_id); obj.delete(:indirect_generation_number) }
    end

    def rebuild_names(name_tree = nil, base = 'CombinePDF_0000000')
      if name_tree
        dic = []
        case name_tree
        when Array
          if name_tree[0].is_a? String
            (name_tree.length / 2).times do |i|
              dic << (name_tree[i * 2].clear << base.next!)
              dic << name_tree[(i * 2) + 1]
            end
          else
            name_tree.each { |kid| dic.concat rebuild_names(kid, base) }
          end
        when Hash
          if name_tree[:Kids]
            dic.concat rebuild_names(name_tree[:Kids], base)
          elsif name_tree[:Names]
            dic.concat rebuild_names(name_tree[:Names], base)
          elsif name_tree[:referenced_object]
            dic.concat rebuild_names(name_tree[:referenced_object], base)
          end
        end
        return dic
      end
      @names.keys.each do |k|
        @names[k] = { referenced_object: { Names: rebuild_names(@names[k], base) }, is_reference_only: true } unless k == :Type
      end
    end

    # @private
    # this method reviews a Hash an updates it by merging Hash data,
    # preffering the new over the old.
    def self.hash_merge_new_no_page(_key, old_data, new_data)
      if old_data.is_a? Hash
        return old_data if old_data[:Type] == :Page
        old_data.merge(new_data, &(@hash_merge_new_no_page_proc ||= method(:hash_merge_new_no_page)))
      elsif old_data.is_a? Array
        old_data + new_data
      else
        new_data
      end
    end

		def merge_outlines(old_data, new_data, position)
		  old_data = actual_object(old_data)
		  new_data = actual_object(new_data).dup
		  if old_data.empty?
		    # old_data is a reference to the actual object,
		    # so if we update old_data, we're done, no need to take any further action
		    old_data.update new_data
		  else
		    old_data[:Count] += new_data[:Count]
		    # walk the Hash here ...
		    # I'm just using the start / finish position for now...
		    # FIXME to implement an insert in the middle of the file?
		    prev = nil
		    pos = first = actual_object(((position < 0) ? new_data : old_data)[:First])
		    last = actual_object(((position < 0) ? old_data : new_data)[:Last])
				median = {is_reference_only: true, referenced_object: actual_object(((position < 0) ? old_data : new_data)[:First])}
		    old_data[:First] = {is_reference_only: true, referenced_object: first}
		    old_data[:Last] = {is_reference_only: true, referenced_object: last}
		    parent = {is_reference_only: true, referenced_object: old_data}
		    # the walking
		    while(pos)
	        # pos[:First] = first # already a reference
	        # pos[:Last] = last # already a reference
	        pos[:Parent] = parent if pos[:Parent] # already a reference
	        if(prev)
	          pos[:Prev] = {is_reference_only: true, referenced_object: prev}
	        else
	          pos.delete :Prev
	        end
	        # connect the two outlines
	        if(pos[:Next].nil?)
	          pos[:Next] = median
	          median = nil
	        end
	        prev = pos
	        pos = actual_object(pos[:Next])
		    end
		    # make sure the last object doesn't have the :Next property
		    prev.delete :Next
		  end
		  # print_dat_outline(old_data)
		  return nil # no need to return the data, the update had taken place destructively.
		end

				def merge_outlines(old_data, new_data)
			if old_data.empty?
				old_data = new_data
	  else
				old_data[:Count] += new_data[:Count]
				update_parents(old_data, old_data)
				update_parents(new_data, old_data)
				old_data[:Last] = new_data[:Last]
				append_new_outline(old_data[:First][:referenced_object], new_data[:First])
			end
			# print_dat_outline(old_data)
			return old_data
		end

		def update_parents(data, new_parent)
			update_parents_subtree(data[:First][:referenced_object], new_parent) if data[:Type] == :Outlines
			update_parents_subtree(data[:Last][:referenced_object], new_parent) if data[:Type] == :Outlines
		end

		def update_parents_subtree(new_data, new_parent)
			new_data[:Parent] = {is_reference_only: true, referenced_object: new_parent} if new_data[:Parent]
			update_parents_subtree(new_data[:Next][:referenced_object], new_parent) if new_data[:Next]
		end

		def append_new_outline(outline, next_to_append)
			if outline[:Next]
				append_new_outline(outline[:Next][:referenced_object], next_to_append)
			else
				outline[:Next] = next_to_append
				next_to_append[:referenced_object][:Prev] = {is_reference_only: true, referenced_object: outline}
		  end
	  end

		def print_dat_outline(ol)
			xy = ol.to_s.gsub(/\:raw_stream_content=\>"[^"]+",/,":raw_stream_content=> RAW STREAM")
			xy = xy.gsub(/\:raw_stream_content=\>"(?:(?!"}).)*+"\}/,":raw_stream_content=> RAW STREAM}")
			brace_cnt = 0
			new_xy = ""
			xy.each_char do |c|
				if c == '{'
					new_xy << "\n" << "\t" * brace_cnt << c
					brace_cnt += 1
				elsif c == '}'
					brace_cnt -= 1
					new_xy << c << "\n" << "\t" * brace_cnt
				elsif c == '\n'
					new_xy << c << "\t" * brace_cnt
				else
					new_xy << c
				end
			end
			File.open("combine_pdf_out.txt", 'w') { |file| file.write(new_xy) }
		end

    private

    def renaming_dictionary(object = nil, dictionary = {})
      object ||= @names
      case object
      when Array
        object.length.times { |i| object[i].is_a?(String) ? (dictionary[object[i]] = (dictionary.last || 'Random_0001').next) : renaming_dictionary(object[i], dictionary) }
      when Hash
        object.values.each { |v| renaming_dictionary v, dictionary }
      end
    end

    def rename_object(object, _dictionary)
      case object
      when Array
        object.length.times { |i| }
      when Hash
      end
    end
  end
end
