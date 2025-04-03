# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################

module CombinePDF
  ParsingError = Class.new(StandardError)

  # @!visibility private
  # @private
  #:nodoc: all

  protected

  # This is the Parser class.
  #
  # It takes PDF data and parses it.
  #
  # The information is then used to initialize a PDF object.
  #
  # This is an internal class. you don't need it.
  class PDFParser
    # @!visibility private

    # the array containing all the parsed data (PDF Objects)
    attr_reader :parsed
    # a Float representing the PDF version of the data parsed (if exists).
    attr_reader :version
    # the info and root objects, as found (if found) in the PDF file.
    #
    # they are mainly to used to know if the file is (was) encrypted and to get more details.
    attr_reader :info_object, :root_object, :names_object, :forms_object, :outlines_object, :metadata

    attr_reader :allow_optional_content, :raise_on_encrypted
    # when creating a parser, it is important to set the data (String) we wish to parse.
    #
    # <b>the data is required and it is not possible to set the data at a later stage</b>
    #
    # string:: the data to be parsed, as a String object.
    def initialize(string, options = {})
      raise TypeError, "couldn't parse data, expecting type String" unless string.is_a? String
      @string_to_parse = (string.frozen? ? string.dup : string).force_encoding(Encoding::ASCII_8BIT)
      @literal_strings = [].dup
      @hex_strings = [].dup
      @streams = [].dup
      @parsed = [].dup
      @references = [].dup
      @root_object = {}.dup
      @info_object = {}.dup
      @names_object = {}.dup
      @outlines_object = {}.dup
      @forms_object = {}.dup
      @metadata = nil
      @strings_dictionary = {}.dup # all strings are one string
      @resolution_hash = {}.dup
      @version = nil
      @scanner = nil
      @allow_optional_content = options[:allow_optional_content]
      @raise_on_encrypted = options[:raise_on_encrypted]
    end

    # parse the data in the new parser (the data already set through the initialize / new method)
    def parse
      return [] if @string_to_parse.empty?
      return @parsed unless @parsed.empty?
      @scanner = StringScanner.new @string_to_parse
      @scanner.pos = 0
      @scanner.skip(/[^%]*/) if @scanner.exist?(/%PDF/i)
      if @scanner.scan(/\%PDF\-[\d\-\.]+/)
        @version = @scanner.matched.scan(/[\d\.]+/)[0].to_f
        loop do
          break unless @scanner.scan(/[^\d\r\n]+/)
          break if @scanner.check(/([\d]+[\s]+[\d]+[\s]+obj[\s]+\<\<)|([\n\r]+)/)
          break if @scanner.eos?
          @scanner.pos += 1
        end
      end
      @parsed = _parse_
      # puts @parsed

      unless (@parsed.select { |i| !i.is_a?(Hash) }).empty?
        # p @parsed.select
        raise ParsingError, 'Unknown PDF parsing error - malformed PDF file?'
      end

      if @root_object == {}.freeze
        xref_streams = @parsed.select { |obj| obj.is_a?(Hash) && obj[:Type] == :XRef }
        xref_streams.each do |xref_dictionary|
          @root_object.merge! xref_dictionary
        end
      end

      if @root_object == {}.freeze
        raise ParsingError, 'root is unknown - cannot determine if file is Encrypted'
      end

      if @root_object[:Encrypt]
        raise EncryptionError, 'the file is encrypted' if @raise_on_encrypted
        # change_references_to_actual_values @root_object
        warn 'PDF is Encrypted! Attempting to decrypt - not yet fully supported.'
        decryptor = PDFDecrypt.new @parsed, @root_object
        decryptor.decrypt
        # do we really need to apply to @parsed? No, there is no need.
      end

      # search for objects streams and replace them "in-place"
      # the inplace resolution prevents versioning errors
      while (true)
        found_object_streams = false
        @parsed.length.times do |i|
          o = @parsed[i]
          next unless o.is_a?(Hash) && o[:Type] == :ObjStm
          ## un-encode (using the correct filter) the object streams
          PDFFilter.inflate_object o
          # puts "Object Stream Found:", o[:raw_stream_content]
          ## extract objects from stream
          @scanner = StringScanner.new o[:raw_stream_content]
          stream_data = _parse_
          id_array = []
          collection = [nil]
          while (stream_data[0].is_a?(Numeric) && stream_data[1].is_a?(Numeric))
            id_array << stream_data.shift
            stream_data.shift
          end
          while id_array[0] && stream_data[0]
            stream_data[0] = { indirect_without_dictionary: stream_data[0] } unless stream_data[0].is_a?(Hash)
            stream_data[0][:indirect_reference_id] = id_array.shift
            stream_data[0][:indirect_generation_number] = 0
            collection << (stream_data.shift)
          end
          # place new objects right after this one (removing this one as well)
          @parsed[i] = collection
          found_object_streams = true
        end
        break unless found_object_streams
        @parsed.flatten!
        @parsed.compact!
      end

      #
      # object_streams = @parsed.select { |obj| obj.is_a?(Hash) && obj[:Type] == :ObjStm }
      # unless object_streams.empty?
      #   warn 'PDF 1.5 Object streams found - they are not fully supported! attempting to extract objects.'
      #
      #   object_streams.each do |o|
      #     ## un-encode (using the correct filter) the object streams
      #     PDFFilter.inflate_object o
      #     ## extract objects from stream to top level arry @parsed
      #     @scanner = StringScanner.new o[:raw_stream_content]
      #     stream_data = _parse_
      #     id_array = []
      #     while stream_data[0].is_a? (Numeric)
      #       id_array << stream_data.shift
      #       stream_data.shift
      #     end
      #     while id_array[0] && stream_data[0]
      #       stream_data[0] = { indirect_without_dictionary: stream_data[0] } unless stream_data[0].is_a?(Hash)
      #       stream_data[0][:indirect_reference_id] = id_array.shift
      #       stream_data[0][:indirect_generation_number] = 0
      #       @parsed << stream_data.shift
      #     end
      #   end
      # end

      # serialize_objects_and_references.catalog_pages

      # Benchmark.bm do |bm|
      # 	bm.report("serialize") {1000.times {serialize_objects_and_references} }
      # 	bm.report("serialize - old") {1000.times {old_serialize_objects_and_references} }
      # 	bm.report("catalog") {1000.times {catalog_pages} }
      # end

      serialize_objects_and_references

      catalog_pages

      # Strings were unified, we can let them go..
      @strings_dictionary.clear

      # collect any missing objects from the forms_data
      unless @forms_object.nil? || @forms_object.empty?
        @forms_object[:related_objects] = (@parsed.select { |o| o[:FT] }).map! { |o| { is_reference_only: true, referenced_object: o } }
        @forms_object[:related_objects].delete @forms_object
      end

      @info_object = @root_object[:Info] ? (@root_object[:Info][:referenced_object] || @root_object[:Info]) : false
      if @info_object && @info_object.is_a?(Hash)
        @parsed.delete @info_object
        CombinePDF::PDF::PRIVATE_HASH_KEYS.each { |key| @info_object.delete key }
        @info_object.each { |_k, v| @info_object = v[:referenced_object] if v.is_a?(Hash) && v[:referenced_object] }
      else
        @info_object = {}
      end

      # we can clear the resolution hash now
      @resolution_hash.clear if @resolution_hash
      # # # ## remove object streams - if they exist
      # @parsed.reject! {|obj| object_streams << obj if obj.is_a?(Hash) && obj[:Type] == :ObjStm}
      # # # ## remove XREF dictionaries - if they exist
      # @parsed.reject! {|obj| object_streams << obj if obj.is_a?(Hash) && obj[:Type] == :XRef}

      @parsed
    end

    # the actual recoursive parsing is done here.
    #
    # this is an internal function, but it was left exposed for posible future features.
    def _parse_
      out = []
      str = ''
      fresh = true
      while @scanner.rest?
        # last ||= 0
        # out.last.tap do |o|
        # 	if o.is_a?(Hash)
        # 		puts "[#{@scanner.pos}] Parser has a Dictionary (#{o.class.name}) with data:"
        # 		o.each do |k, v|
        # 			puts "    #{k}: is #{v.class.name} with data: #{v.to_s[0..4]}#{"..." if v.to_s.length > 5}"
        # 		end
        # 	else
        # 		puts "[#{@scanner.pos}] Parser has #{o.class.name} with data: #{o.to_s[0..4]}#{"..." if o.to_s.length > 5}"
        # 	end
        # 	puts "next is #{@scanner.peek 8}"
        # end unless (last == out.count) || (-1 == (last = out.count))
        if @scanner.scan(/\[/)
          out << _parse_
        ##########################################
        ## Parse a Name
        ##########################################
        # old, probably working version: when str = @scanner.scan(/\/[\#\w\d\.\+\-\\\?\,]+/)
        # I don't know how to write the /[\x21-\x7e___subtract_certain_hex_values_here____]+/
        # all allowed regular caracters between ! and ~ : /[\x21-\x24\x26\x27\x2a-\x2e\x30-\x3b\x3d\x3f-\x5a\x5c\x5e-\x7a\x7c\x7e]+
        # all characters that aren't white space or special: /[^\x00\x09\x0a\x0c\x0d\x20\x28\x29\x3c\x3e\x5b\x5d\x7b\x7d\x2f\x25]+
        elsif str = @scanner.scan(/\/[^\x00\x09\x0a\x0c\x0d\x20\x28\x29\x3c\x3e\x5b\x5d\x7b\x7d\x2f\x25]*/)
          out << (str[1..-1].gsub(/\#[0-9a-fA-F]{2}/) { |a| a[1..2].hex.chr }).to_sym
          # warn "CombinePDF detected name: #{out.last.to_s}"
        ##########################################
        ## Parse a Number
        ##########################################
        elsif str = @scanner.scan(/[\+\-\.\d]+/)
          str =~ /\./ ? (out << str.to_f) : (out << str.to_i)
          # warn "CombinePDF detected number: #{out.last.to_s}"
        ##########################################
        ## parse a Hex String
        ##########################################
        elsif str = @scanner.scan(/\<[0-9a-fA-F]*\>/)
          # warn "Found a hex string #{str}"
          str = str.slice(1..-2).force_encoding(Encoding::ASCII_8BIT)
          # str = "0#{str}" if str.length.odd?
          out << unify_string([str].pack('H*').force_encoding(Encoding::ASCII_8BIT))
        ##########################################
        ## parse a space delimited Hex String
        ##########################################
        elsif str = @scanner.scan(/\<[0-9a-fA-F\s]*\>/)
          # warn "Found a space seperated hex string"
          str = str.force_encoding(Encoding::ASCII_8BIT).split(/\s/).map! {|b| b.length.odd? ? "0#{b}" : b}
          out << unify_string(str.pack('H*' * str.length).force_encoding(Encoding::ASCII_8BIT))
        ##########################################
        ## parse a Literal String
        ##########################################
        elsif @scanner.scan(/\(/)
          # warn "Found a literal string"
          str = ''.b
          count = 1
          while count > 0 && @scanner.rest?
            scn = @scanner.scan_until(/[\(\)]/)
            unless scn
              warn "Unknown error parsing string at #{@scanner.pos} for string: #{str}!"
              count = 0 # error
              next
            end

            str += scn.to_s
            seperator_count = 0
            seperator_count += 1 while str[-2 - seperator_count] == '\\'

            case str[-1]
            when '('
              ## The following solution might fail when (string ends with this sign: \\)
              count += 1 unless seperator_count.odd?
            when ')'
              count -= 1 unless seperator_count.odd?
            else
              warn "Unknown error parsing string at #{@scanner.pos} for string: #{str}!"
              count = 0 # error
            end
          end
          # The PDF formatted string is: str[0..-2]
          # now starting to convert to regular string
          str_bytes = str.force_encoding(Encoding::ASCII_8BIT)[0..-2].bytes.to_a
          str = []
          until str_bytes.empty?
            case str_bytes[0]
            when 13 # eol - \r
              # An end-of-line marker appearing within a literal string without a preceding REVERSE SOLIDUS
              # shall be treated as a byte value of (0Ah),
              # irrespective of whether the end-of-line marker was a CARRIAGE RETURN (0Dh), a LINE FEED (0Ah), or both.
              str_bytes.shift
              str_bytes.shift if str_bytes[0] == 10
              str << 10
            when 10 # eol - \n
              # An end-of-line marker appearing within a literal string without a preceding REVERSE SOLIDUS
              # shall be treated as a byte value of (0Ah),
              # irrespective of whether the end-of-line marker was a CARRIAGE RETURN (0Dh), a LINE FEED (0Ah), or both.
              str_bytes.shift
              str_bytes.shift if str_bytes[0] == 13
              str << 10
            when 92 # "\\".ord == 92
              str_bytes.shift
              rep = str_bytes.shift
              case rep
              when 110 # n
                str << 10 # new line
              when 114 # r
                str << 13 # CR
              when 116 # t
                str << 9 # tab
              when 98 # b
                str << 8
              when 102 # f, form-feed
                str << 12
              when 48..57 # octal notation for byte?
                rep -= 48
                rep = (rep << 3) + (str_bytes.shift-48) if str_bytes[0]&.between?(48, 57)
                rep = (rep << 3) + (str_bytes.shift-48) if str_bytes[0]&.between?(48, 57) && (((rep << 3) + (str_bytes[0] - 48)) <= 255)
                str << rep
              when 10 # new line, ignore
                str_bytes.shift if str_bytes[0] == 13
                true
              when 13 # new line (or double notation for new line), ignore
                str_bytes.shift if str_bytes[0] == 10
                true
              else
                str << rep
              end
            else
              str << str_bytes.shift
            end
          end
          out << unify_string(str.pack('C*').force_encoding(Encoding::ASCII_8BIT))
          # warn "Found Literal String: #{out.last}"
        ##########################################
        ## parse a Dictionary
        ##########################################
        elsif @scanner.scan(/<</)
          data = _parse_
          obj = {}
          obj[data.shift] = data.shift while data[0]
          out << obj
        ##########################################
        ## return content of array or dictionary
        ##########################################
        elsif @scanner.scan(/\]/) || @scanner.scan(/>>/)
          # warn "Dictionary / Array ended with #{@scanner.peek(5)}"
          return out
        ##########################################
        ## parse a Stream
        ##########################################
        elsif @scanner.scan(/stream[ \t]*\r?\n?/)
          # advance by the publshed stream length (if any)
          old_pos = @scanner.pos
          if(out.last.is_a?(Hash) && out.last[:Length].is_a?(Integer) && out.last[:Length])
            @scanner.pos += out.last[:Length]
            unless(@scanner.skip(/\r?\n?endstream/))
              @scanner.pos = old_pos 
              # raise error if the stream doesn't end.
              unless @scanner.skip_until(/endstream/)
                raise ParsingError, "Parsing Error: PDF file error - a stream object wasn't properly closed using 'endstream'!"
              end
            end
          else
            # raise error if the stream doesn't end.
            unless @scanner.skip_until(/endstream/)
              raise ParsingError, "Parsing Error: PDF file error - a stream object wasn't properly closed using 'endstream'!"
            end
          end

          length = @scanner.pos - (old_pos + 9)
          length = 0 if(length < 0)
          length -= 1 if(@scanner.string[old_pos + length - 1] == "\n") 
          length -= 1 if(@scanner.string[old_pos + length - 1] == "\r") 
          str = (length > 0) ? @scanner.string.slice(old_pos, length) : +''

          # warn "CombinePDF parser: detected Stream #{str.length} bytes long #{str[0..3]}...#{str[-4..-1]}"

          # need to remove end of stream
          if out.last.is_a? Hash
            out.last[:raw_stream_content] = unify_string str.force_encoding(Encoding::ASCII_8BIT)
          else
            warn 'Stream not attached to dictionary!'
            out << str.force_encoding(Encoding::ASCII_8BIT)
          end
        ##########################################
        ## parse an Object after finished
        ##########################################
        elsif str = @scanner.scan(/endobj/)
          # what to do when this is an object?
          if out.last.is_a? Hash
            out << out.pop.merge(indirect_generation_number: out.pop, indirect_reference_id: out.pop)
          else
            out << { indirect_without_dictionary: out.pop, indirect_generation_number: out.pop, indirect_reference_id: out.pop }
          end
          fresh = true
          # fix wkhtmltopdf use of PDF 1.1 Dest using symbols instead of strings
          out.last[:Dest] = unify_string(out.last[:Dest].to_s) if out.last[:Dest] && out.last[:Dest].is_a?(Symbol)
        # puts "!!!!!!!!! Error with :indirect_reference_id\n\nObject #{out.last}  :indirect_reference_id = #{out.last[:indirect_reference_id]}" unless out.last[:indirect_reference_id].is_a?(Numeric)
        ##########################################
        ## Parse an Object Reference
        ##########################################
        elsif @scanner.scan(/R/)
          out << { is_reference_only: true, indirect_generation_number: out.pop, indirect_reference_id: out.pop }
        # @references << out.last
        ##########################################
        ## Parse Bool - true and after false
        ##########################################
        elsif @scanner.scan(/true/)
          out << true
        elsif @scanner.scan(/false/)
          out << false
        ##########################################
        ## Parse NULL - null
        ##########################################
        elsif @scanner.scan(/null/)
          out << nil
        ##########################################
        ## Parse file trailer
        ##########################################
        elsif @scanner.scan(/trailer/)
          if @scanner.skip_until(/<</)
            data = _parse_
            (@root_object ||= {}).clear
            @root_object[data.shift] = data.shift while data[0]
          end
        ##########################################
        ## XREF - check for encryption... anything else?
        ##########################################
        elsif @scanner.scan(/xref/)
          # skip list indetifier lines or list lines ([\d] [\d][\r\n]) ot ([\d] [\d] [nf][\r\n])
          while @scanner.scan(/[\s]*[\d]+[ \t]+[\d]+[ \t]*[\n\r]+/) || @scanner.scan(/[ \t]*[\d]+[ \t]+[\d]+[ \t]+[nf][\s]*/)
            nil
          end
        ##########################################
        ## XREF location can be ignored
        ##########################################
        elsif @scanner.scan(/startxref/)
          @scanner.scan(/[\s]+[\d]+[\s]+/)
        ##########################################
        ## Skip Whitespace
        ##########################################
        elsif @scanner.scan(/[\s]+/)
          # Generally, do nothing
          nil
        ##########################################
        ## EOF?
        ##########################################
        elsif @scanner.scan(/\%\%EOF/)
          ##########
          ## If this was the last valid segment, ignore any trailing garbage
          ## (issue #49 resolution)
          break unless @scanner.exist?(/\%\%EOF/)
        ##########################################
        ## Parse a comment
        ##########################################
        elsif str = @scanner.scan(/\%/)
          # is a comment, skip until new line
          loop do
            # break unless @scanner.scan(/[^\d\r\n]+/)
            break if @scanner.check(/([\d]+[\s]+[\d]+[\s]+obj[\s]+\<\<)|([\n\r]+)/) || @scanner.eos? # || @scanner.scan(/[^\d]+[\r\n]+/) ||
            @scanner.scan(/[^\d\r\n]+/) || @scanner.pos += 1
          end
        # puts "AFTER COMMENT: #{@scanner.peek 8}"
        ##########################################
        ## Fix wkhtmltopdf - missing 'endobj' keywords
        ##########################################
        elsif @scanner.scan(/obj[\s]*/)
          # Fix wkhtmltopdf PDF authoring issue - missing 'endobj' keywords
          unless fresh || (out[-4].nil? || out[-4].is_a?(Hash))
            keep = []
            keep << out.pop # .tap {|i| puts "#{i} is an ID"}
            keep << out.pop # .tap {|i| puts "#{i} is a REF"}

            if out.last.is_a? Hash
              out << out.pop.merge(indirect_generation_number: out.pop, indirect_reference_id: out.pop)
            else
              out << { indirect_without_dictionary: out.pop, indirect_generation_number: out.pop, indirect_reference_id: out.pop }
            end
            # fix wkhtmltopdf use of PDF 1.1 Dest using symbols instead of strings
            out.last[:Dest] = unify_string(out.last[:Dest].to_s) if out.last[:Dest] && out.last[:Dest].is_a?(Symbol)
            warn "'endobj' keyword was missing for Object ID: #{out.last[:indirect_reference_id]}, trying to auto-fix issue, but might fail."

            out << keep.pop
            out << keep.pop
          end
          fresh = false
        ##########################################
        ## Unknown, warn and advance
        ##########################################
        else
          # always advance
          # warn "Advancing for unknown reason... #{@scanner.string[@scanner.pos - 4, 8]} ... #{@scanner.peek(4)}" unless @scanner.peek(1) =~ /[\s\n]/
          warn 'Warning: parser advancing for unknown reason. Potential data-loss.'
          @scanner.pos = @scanner.pos + 1
        end
      end
      out
    end

    protected

    # resets cataloging and pages
    def catalog_pages(catalogs = nil, inheritance_hash = {})
      unless catalogs

        if root_object[:Root]
          catalogs = root_object[:Root][:referenced_object] || root_object[:Root]
        else
          catalogs = (@parsed.select { |obj| obj[:Type] == :Catalog }).last
        end

        @parsed.delete_if { |obj| obj.nil? || obj[:Type] == :Catalog }
        @parsed << catalogs

        unless catalogs
          raise ParsingError, "Unknown error - parsed data doesn't contain a cataloged object!"
        end
      end
      if catalogs.is_a?(Array)
        catalogs.each { |c| catalog_pages(c, inheritance_hash) unless c.nil? }
      elsif catalogs.is_a?(Hash)
        if catalogs[:is_reference_only]
          if catalogs[:referenced_object]
            catalog_pages(catalogs[:referenced_object], inheritance_hash)
          else
            warn "couldn't follow reference!!! #{catalogs} not found!"
          end
        else
          unless catalogs[:Type] == :Page
            if (catalogs[:AS] || catalogs[:OCProperties]) && !@allow_optional_content
              raise ParsingError, "Optional Content PDF files aren't supported and their pages cannot be safely extracted."
            end

            inheritance_hash[:MediaBox] = catalogs[:MediaBox] if catalogs[:MediaBox]
            inheritance_hash[:CropBox] = catalogs[:CropBox] if catalogs[:CropBox]
            inheritance_hash[:Rotate] = catalogs[:Rotate] if catalogs[:Rotate]
            if catalogs[:Resources]
              inheritance_hash[:Resources] ||= { referenced_object: {}, is_reference_only: true }.dup
              (inheritance_hash[:Resources][:referenced_object] || inheritance_hash[:Resources]).update((catalogs[:Resources][:referenced_object] || catalogs[:Resources]), &HASH_UPDATE_PROC_FOR_OLD)
            end
            if catalogs[:ProcSet].is_a?(Array)
              if(inheritance_hash[:ProcSet])
                inheritance_hash[:ProcSet][:referenced_object].concat(catalogs[:ProcSet])
                inheritance_hash[:ProcSet][:referenced_object].uniq!
              else
                inheritance_hash[:ProcSet] ||= { referenced_object: catalogs[:ProcSet], is_reference_only: true }.dup
              end
            end
            if catalogs[:ColorSpace]
              inheritance_hash[:ColorSpace] ||= { referenced_object: {}, is_reference_only: true }.dup
              (inheritance_hash[:ColorSpace][:referenced_object] || inheritance_hash[:ColorSpace]).update((catalogs[:ColorSpace][:referenced_object] || catalogs[:ColorSpace]), &HASH_UPDATE_PROC_FOR_OLD)
            end
            # (inheritance_hash[:Resources] ||= {}).update((catalogs[:Resources][:referenced_object] || catalogs[:Resources]), &HASH_UPDATE_PROC_FOR_NEW) if catalogs[:Resources]
            # (inheritance_hash[:ColorSpace] ||= {}).update((catalogs[:ColorSpace][:referenced_object] || catalogs[:ColorSpace]), &HASH_UPDATE_PROC_FOR_NEW) if catalogs[:ColorSpace]

            # inheritance_hash[:Order] = catalogs[:Order] if catalogs[:Order]
            # inheritance_hash[:OCProperties] = catalogs[:OCProperties] if catalogs[:OCProperties]
            # inheritance_hash[:AS] = catalogs[:AS] if catalogs[:AS]
          end

          case catalogs[:Type]
          when :Page

            catalogs[:MediaBox] ||= inheritance_hash[:MediaBox] if inheritance_hash[:MediaBox]
            catalogs[:CropBox] ||= inheritance_hash[:CropBox] if inheritance_hash[:CropBox]
            catalogs[:Rotate] ||= inheritance_hash[:Rotate] if inheritance_hash[:Rotate]
            if inheritance_hash[:Resources]
              catalogs[:Resources] ||= { referenced_object: {}, is_reference_only: true }.dup
              catalogs[:Resources] = { referenced_object: catalogs[:Resources], is_reference_only: true } unless catalogs[:Resources][:referenced_object]
              catalogs[:Resources][:referenced_object].update((inheritance_hash[:Resources][:referenced_object] || inheritance_hash[:Resources]), &HASH_UPDATE_PROC_FOR_OLD)
            end
            if inheritance_hash[:ColorSpace]
              catalogs[:ColorSpace] ||= { referenced_object: {}, is_reference_only: true }.dup
              catalogs[:ColorSpace] = { referenced_object: catalogs[:ColorSpace], is_reference_only: true } unless catalogs[:ColorSpace][:referenced_object]
              catalogs[:ColorSpace][:referenced_object].update((inheritance_hash[:ColorSpace][:referenced_object] || inheritance_hash[:ColorSpace]), &HASH_UPDATE_PROC_FOR_OLD)
            end
            if inheritance_hash[:ProcSet]
              if(catalogs[:ProcSet])
                if catalogs[:ProcSet].is_a?(Array)
                  catalogs[:ProcSet] = { referenced_object: catalogs[:ProcSet], is_reference_only: true }
                end
                catalogs[:ProcSet][:referenced_object].concat(inheritance_hash[:ProcSet][:referenced_object])
                catalogs[:ProcSet][:referenced_object].uniq!
              else
                catalogs[:ProcSet] = { is_reference_only: true }.dup
                catalogs[:ProcSet][:referenced_object] = []
              end
            end
            # (catalogs[:ColorSpace] ||= {}).update(inheritance_hash[:ColorSpace], &HASH_UPDATE_PROC_FOR_OLD) if inheritance_hash[:ColorSpace]
            # catalogs[:Order] ||= inheritance_hash[:Order] if inheritance_hash[:Order]
            # catalogs[:AS] ||= inheritance_hash[:AS] if inheritance_hash[:AS]
            # catalogs[:OCProperties] ||= inheritance_hash[:OCProperties] if inheritance_hash[:OCProperties]

            # avoide references on MediaBox, CropBox and Rotate
            catalogs[:MediaBox] = catalogs[:MediaBox][:referenced_object][:indirect_without_dictionary] if catalogs[:MediaBox].is_a?(Hash) && catalogs[:MediaBox][:referenced_object].is_a?(Hash) && catalogs[:MediaBox][:referenced_object][:indirect_without_dictionary]
            catalogs[:CropBox] = catalogs[:CropBox][:referenced_object][:indirect_without_dictionary] if catalogs[:CropBox].is_a?(Hash) && catalogs[:CropBox][:referenced_object].is_a?(Hash) && catalogs[:CropBox][:referenced_object][:indirect_without_dictionary]
            catalogs[:Rotate] = catalogs[:Rotate][:referenced_object][:indirect_without_dictionary] if catalogs[:Rotate].is_a?(Hash) && catalogs[:Rotate][:referenced_object].is_a?(Hash) && catalogs[:Rotate][:referenced_object][:indirect_without_dictionary]

            catalogs.instance_eval { extend Page_Methods }
          when :Pages
            catalog_pages(catalogs[:Kids], inheritance_hash.dup) unless catalogs[:Kids].nil?
          when :Catalog
            @forms_object.update((catalogs[:AcroForm][:referenced_object] || catalogs[:AcroForm]), &HASH_UPDATE_PROC_FOR_NEW) if catalogs[:AcroForm]
            @names_object.update((catalogs[:Names][:referenced_object] || catalogs[:Names]), &HASH_UPDATE_PROC_FOR_NEW) if catalogs[:Names]
            @outlines_object.update((catalogs[:Outlines][:referenced_object] || catalogs[:Outlines]), &HASH_UPDATE_PROC_FOR_NEW) if catalogs[:Outlines]
            if catalogs[:Dests] # convert PDF 1.1 Dests to PDF 1.2+ Dests
              dests_arry = (@names_object[:Dests] ||= {})
              dests_arry = ((dests_arry[:referenced_object] || dests_arry)[:Names] ||= [])
              ((catalogs[:Dests][:referenced_object] || catalogs[:Dests])[:referenced_object] || (catalogs[:Dests][:referenced_object] || catalogs[:Dests])).each {|k,v| next if CombinePDF::PDF::PRIVATE_HASH_KEYS.include?(k); dests_arry << unify_string(k.to_s); dests_arry << v; }
            end
            catalog_pages(catalogs[:Pages], inheritance_hash.dup) unless catalogs[:Pages].nil?
          end
        end
      end
      self
    end

    # @private
    # connects references and objects, according to their reference id's.
    #
    # Also replaces :indirect_without_dictionary objects with their actual values. Strings, Hashes and Arrays still share memory space.
    #
    # should be moved to the parser's workflow.
    #
    def serialize_objects_and_references
      obj_dir = {}
      objid_cache = {}.compare_by_identity
      # create a dictionary for referenced objects (no value resolution at this point)
      # at the same time, delete duplicates and old versions when objects have multiple versions
      @parsed.uniq!
      @parsed.length.times do |i|
        o = @parsed[i]
        objid_cache[o] = i
        tmp_key = [o[:indirect_reference_id], o[:indirect_generation_number]]
        if tmp_found = obj_dir[tmp_key]
          tmp_found.clear
          @parsed[objid_cache[tmp_found]] = nil
        end
        obj_dir[tmp_key] = o
      end
      @parsed.compact!
      objid_cache.clear

      should_resolve = [@parsed, @root_object]
      while should_resolve.count > 0
        obj = should_resolve.pop
        if obj.is_a?(Hash)
          obj.keys.each do |k|
            o = obj[k]
            if o.is_a?(Hash)
              if o[:is_reference_only]
                if o[:indirect_reference_id].nil?
                  o = nil
                else
                  o[:referenced_object] = obj_dir[[o[:indirect_reference_id], o[:indirect_generation_number]]]
                  warn "Couldn't connect reference for #{o}" if o[:referenced_object].nil? && (o[:indirect_reference_id] + o[:indirect_generation_number] != 0)
                  o.delete :indirect_reference_id
                  o.delete :indirect_generation_number
                  o = (o[:referenced_object] && o[:referenced_object][:indirect_without_dictionary]) || o
                end
                obj[k] = o
              else
                should_resolve << o
              end
            elsif o.is_a?(Array)
              should_resolve << o
            end
          end
        elsif obj.is_a?(Array)
          obj.map! do |o|
            if o.is_a?(Hash)
              if o[:is_reference_only]
                if o[:indirect_reference_id].nil?
                  o = nil
                else
                  o[:referenced_object] = obj_dir[[o[:indirect_reference_id], o[:indirect_generation_number]]]
                  warn "Couldn't connect reference for #{o}" if o[:referenced_object].nil?
                  o.delete :indirect_reference_id
                  o.delete :indirect_generation_number
                  o = (o[:referenced_object] && o[:referenced_object][:indirect_without_dictionary]) || o
                end
              else
                should_resolve << o
              end
            elsif o.is_a?(Array)
              should_resolve << o
            end
            o
          end
        end
      end
    end

    # def serialize_objects_and_references
    #   rec_resolve = proc do |level|
    #     if level.is_a?(Hash)
    #       if level[:is_reference_only]
    #         level[:referenced_object] = get_refernced_object(level)
    #         level = (level[:referenced_object] && level[:referenced_object][:indirect_without_dictionary]) || level
    #         level.delete :indirect_reference_id
    #         level.delete :indirect_generation_number
    #       else
    #         level.keys.each do |k|
    #           level[k] = rec_resolve.call(level[k]) unless level[k].is_a?(Hash) && level[k][:indirect_reference_id] && level[k][:is_reference_only].nil?
    #         end
    #       end
    #     elsif level.is_a?(Array)
    #       level.map! { |o| rec_resolve.call(o) }
    #     end
    #     level
    #   end
    #   rec_resolve.call(@root_object)
    #   rec_resolve.call(@parsed)
    #   self
    # end

    # All Strings are one String
    def unify_string(str)
      str = str.dup if(str.frozen?)
      str.force_encoding(Encoding::ASCII_8BIT)
      @strings_dictionary[str] ||= str
    end

    # @private
    # this method reviews a Hash and updates it by merging Hash data,
    # preffering the old over the new.
    HASH_UPDATE_PROC_FOR_OLD = Proc.new do |_key, old_data, new_data|
      if old_data.is_a? Hash
        old_data.merge(new_data, &HASH_UPDATE_PROC_FOR_OLD)
      else
        old_data
      end
    end
    # def self.hash_update_proc_for_old(_key, old_data, new_data)
    #   if old_data.is_a? Hash
    #     old_data.merge(new_data, &method(:hash_update_proc_for_old))
    #   else
    #     old_data
    #   end
    # end

    # @private
    # this method reviews a Hash an updates it by merging Hash data,
    # preffering the new over the old.
    HASH_UPDATE_PROC_FOR_NEW = Proc.new do |_key, old_data, new_data|
      if old_data.is_a? Hash
        old_data.merge(new_data, &HASH_UPDATE_PROC_FOR_NEW)
      else
        new_data
      end
    end
    # def self.hash_update_proc_for_new(_key, old_data, new_data)
    #   if old_data.is_a? Hash
    #     old_data.merge(new_data, &method(:hash_update_proc_for_new))
    #   else
    #     new_data
    #   end
    # end

    # # run block of code on evey PDF object (PDF objects are class Hash)
    # def each_object(object, limit_references = true, already_visited = {}.compare_by_identity, &block)
    # 	unless limit_references
    # 		already_visited[object] = true
    # 	end
    # 	case
    # 	when object.is_a?(Array)
    # 		object.each {|obj| each_object(obj, limit_references, already_visited, &block)}
    # 	when object.is_a?(Hash)
    # 		yield(object)
    # 		unless limit_references && object[:is_reference_only]
    # 			object.each do |k,v|
    # 				each_object(v, limit_references, already_visited, &block) unless already_visited[v]
    # 			end
    # 		end
    # 	end
    # end
  end
end
