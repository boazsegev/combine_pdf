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

    # RECORSIVE_PROTECTION = { Parent: true, Last: true}.freeze

    # @private
    # Some PDF objects contain references to other PDF objects.
    #
    # this function adds the references contained in `@objects`.
    #
    # this is used for internal operations, such as injectng data using the << operator.
    def add_referenced
      # add references but not root
      should_resolve = @objects.dup
      dup_pages = nil
      # an existing object map
      resolved = {}.dup
      existing = {}.dup
      @objects.each { |obj| existing[obj.object_id] = obj }
      # loop until should_resolve is empty
      while should_resolve.any?
        obj = should_resolve.pop
        if obj.is_a?(Hash)
          next if resolved[obj.object_id] # the object exists
          resolved[obj.object_id] = obj
          if obj[:referenced_object]
            tmp = resolved[obj[:referenced_object].object_id] || existing[obj[:referenced_object].object_id]
            if tmp
              obj[:referenced_object] = tmp
            else
              tmp = obj[:referenced_object]
              should_resolve << tmp
              @objects << tmp
            end
          else
            obj.keys.each { |k| should_resolve << obj[k] unless k == :Parent || resolved[obj[k].object_id] || !obj[k].is_a?(Enumerable) }
          end
        elsif obj.is_a?(Array)
          next if resolved[obj.object_id]
          resolved[obj.object_id] = obj
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

      # duplicate any non-unique pages - This is a special case to resolve Adobe Acrobat Reader issues (see issues #19 and #81)
      uniqueness = {}.dup
      page_list.each { |page| page = page.dup if uniqueness[page.object_id]; uniqueness[page.object_id] = page }
      page_list = uniqueness.values

      # build new Pages object
      pages_object = { Type: :Pages, Count: page_list.length, Kids: page_list.map { |p| { referenced_object: p, is_reference_only: true } } }

      # clear the uniqueness object
      uniqueness.clear

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
      # fix Acrobat Reader issue with page reference uniqueness (must be unique or older Acrobat Reader fails)
      catalog[:Pages][:referenced_object][:Kids].each { |page| @objects << page[:referenced_object] }
      # adds every referenced object to the @objects (root), addition is performed as pointers rather then copies
      # puts (Benchmark.measure do
      add_referenced
      # end)
      # @objects << @info
      # add_referenced @info
      # add_referenced catalog
      # add_referenced catalog[:Pages]
      # add_referenced catalog[:Names], false
      # add_referenced catalog[:Outlines], false
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

    POSSIBLE_NAME_TREES = [:Dests, :AP, :Pages, :IDS, :Templates, :URLS, :Pages].to_set.freeze

    def rebuild_names(name_tree = nil, base = 'CombinePDF_0000000')
      if name_tree
        return nil unless name_tree.is_a?(Hash)
        name_tree = name_tree[:referenced_object] || name_tree
        dic = []
        # map a names tree and return a valid name tree. Do not recourse.
        should_resolve = [name_tree[:Kids], name_tree[:Names]]
        resolved = [].to_set
        while should_resolve.any?
          pos = should_resolve.pop
          if pos.is_a? Array
            next if resolved.include?(pos.object_id)
            if pos[0].is_a? String
              (pos.length / 2).times do |i|
                dic << (pos[i * 2].clear << base.next!)
                dic << (pos[(i * 2) + 1].is_a?(Array) ? { is_reference_only: true, referenced_object: { indirect_without_dictionary: pos[(i * 2) + 1] } } : pos[(i * 2) + 1])
                # dic << pos[(i * 2) + 1]
              end
            else
              should_resolve.concat pos
            end
          elsif pos.is_a? Hash
            pos = pos[:referenced_object] || pos
            next if resolved.include?(pos.object_id)
            should_resolve << pos[:Kids] if pos[:Kids]
            should_resolve << pos[:Names] if pos[:Names]
          end
          resolved << pos.object_id
        end
        return { referenced_object: { Names: dic }, is_reference_only: true }
      end
      @names ||= @names[:referenced_object]
      new_names = { Type: :Names }.dup
      POSSIBLE_NAME_TREES.each do |ntree|
        if @names[ntree]
          new_names[ntree] = rebuild_names(@names[ntree], base)
          @names[ntree].clear
        end
      end
      @names.clear
      @names = new_names
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

    # Merges 2 outlines by appending one to the end or start of the other.
    # old_data - the main outline, which is also the one that will be used in the resulting PDF.
    # new_data - the outline to be appended
    # position - an integer representing the position where a PDF is being inserted.
    #            This method only differentiates between inserted at the beginning, or not.
    #            Not at the beginning, means the new outline will be added to the end of the original outline.
    # An outline base node (tree base) has :Type, :Count, :First, :Last
    # Every node within the outline base node's :First or :Last can have also have the following pointers to other nodes:
    # :First or :Last (only if the node has a subtree / subsection)
    # :Parent (the node's parent)
    # :Prev, :Next (previous and next node)
    # Non-node-pointer data in these nodes:
    # :Title - the node's title displayed in the PDF outline
    # :Count - Number of nodes in it's subtree (0 if no subtree)
    # :Dest  - node link destination (if the node is linking to something)
    def merge_outlines(old_data, new_data, position)
      old_data = actual_object(old_data)
      new_data = actual_object(new_data)
      if old_data.nil? || old_data.empty? || old_data[:First].nil?
        # old_data is a reference to the actual object,
        # so if we update old_data, we're done, no need to take any further action
        old_data.update new_data
      elsif new_data.nil? || new_data.empty? || new_data[:First].nil?
        return old_data
      else
        new_data = new_data.dup # avoid old data corruption
        # number of outline nodes, after the merge
        old_data[:Count] = old_data[:Count].to_i + new_data[:Count].to_i
        # walk the Hash here ...
        # I'm just using the start / end insert-position for now...
        # first  - is going to be the start of the outline base node's :First, after the merge
        # last   - is going to be the end   of the outline base node's :Last,  after the merge
        # median - the start of what will be appended to the end of the outline base node's :First
        # parent - the outline base node of the resulting merged outline
        # FIXME implement the possibility to insert somewhere in the middle of the outline
        prev = nil
        pos = first = actual_object((position.nonzero? ? old_data : new_data)[:First])
        last = actual_object((position.nonzero? ? new_data : old_data)[:Last])
        median = { is_reference_only: true, referenced_object: actual_object((position.nonzero? ? new_data : old_data)[:First]) }
        old_data[:First] = { is_reference_only: true, referenced_object: first }
        old_data[:Last] = { is_reference_only: true, referenced_object: last }
        parent = { is_reference_only: true, referenced_object: old_data }
        while pos
          # walking through old_data here and updating the :Parent as we go,
          # this updates the inserted new_data :Parent's as well once it is appended and the
          # loop keeps walking the appended data.
          pos[:Parent] = parent if pos[:Parent]
          # connect the two outlines
          # if there is no :Next, the end of the outline base node's :First is reached and this is
          # where the new data gets appended, the same way you would append to a two-way linked list.
          if pos[:Next].nil?
            median[:referenced_object][:Prev] = { is_reference_only: true, referenced_object: prev } if median
            pos[:Next] = median
            # midian becomes 'nil' because this loop keeps going after the appending is done,
            # to update the parents of the appended tree and we wouldn't want to keep appending it infinitely.
            median = nil
          end
          # iterating over the outlines main nodes (this is not going into subtrees)
          # while keeping every rotations previous node saved
          prev = pos
          pos = actual_object(pos[:Next])
        end
        # make sure the last object doesn't have the :Next and the first no :Prev property
        prev.delete :Next
        actual_object(old_data[:First]).delete :Prev
      end
    end

    # Prints the whole outline hash to a file,
    # with basic indentation and replacing raw streams with "RAW STREAM"
    # (subbing doesn't allways work that great for big streams)
    # outline - outline hash
    # file    - "filename.filetype" string
    def print_outline_to_file(outline, file)
      outline_subbed_str = outline.to_s.gsub(/\:raw_stream_content=\>"(?:(?!"}).)*+"\}\}/, ':raw_stream_content=> RAW STREAM}}')
      brace_cnt = 0
      formatted_outline_str = ''
      outline_subbed_str.each_char do |c|
        if c == '{'
          formatted_outline_str << "\n" << "\t" * brace_cnt << c
          brace_cnt += 1
        elsif c == '}'
          brace_cnt -= 1
          brace_cnt = 0 if brace_cnt < 0
          formatted_outline_str << c << "\n" << "\t" * brace_cnt
        elsif c == '\n'
          formatted_outline_str << c << "\t" * brace_cnt
        else
          formatted_outline_str << c
        end
      end
      formatted_outline_str << "\n" * 10
      File.open(file, 'w') { |file| file.write(formatted_outline_str) }
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
