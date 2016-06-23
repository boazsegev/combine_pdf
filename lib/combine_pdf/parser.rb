# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################




module CombinePDF


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
		attr_reader :info_object, :root_object, :names_object, :forms_object

		# when creating a parser, it is important to set the data (String) we wish to parse.
		#
		# <b>the data is required and it is not possible to set the data at a later stage</b>
		#
		# string:: the data to be parsed, as a String object.
		def initialize (string)
			raise TypeError, "couldn't parse data, expecting type String" unless string.is_a? String
			@string_to_parse = string.force_encoding(Encoding::ASCII_8BIT)
			@literal_strings = []
			@hex_strings = []
			@streams = []
			@parsed = []
			@references = []
			@root_object = {}
			@info_object = {}
			@names_object = {}
			@forms_object = {}
			@strings_dictionary = {} # all strings are one string
			@version = nil
			@scanner = nil
		end

		# parse the data in the new parser (the data already set through the initialize / new method)
		def parse
			return [] if @string_to_parse.empty?
			return @parsed unless @parsed.empty?
			@scanner = StringScanner.new @string_to_parse
			@scanner.pos = 0
			if @scanner.scan /\%PDF\-[\d\-\.]+/
				@version = @scanner.matched.scan(/[\d\.]+/)[0].to_f
				loop do
					break unless @scanner.scan(/[^\d\r\n]+/)
					break if @scanner.check(/([\d]+[\s]+[\d]+[\s]+obj[\n\r\s]+\<\<)|([\n\r]+)/)
					break if @scanner.eos?
					@scanner.pos += 1
				end
			end
			@parsed = _parse_
			# puts @parsed

			raise "Unknown PDF parsing error - maleformed PDF file?" unless (@parsed.select {|i| !i.is_a?(Hash)}).empty?

			if @root_object == {}
				xref_streams = @parsed.select {|obj| obj.is_a?(Hash) && obj[:Type] == :XRef}
				xref_streams.each do |xref_dictionary|
					@root_object.merge! xref_dictionary
				end
			end
			raise "root is unknown - cannot determine if file is Encrypted" if @root_object == {}

			if @root_object[:Encrypt]
				change_references_to_actual_values @root_object
				warn "PDF is Encrypted! Attempting to decrypt - not yet fully supported."
				decryptor = PDFDecrypt.new @parsed, @root_object
				decryptor.decrypt
				#do we really need to apply to @parsed? No, there is no need.
			end

			## search for objects streams
			object_streams = @parsed.select {|obj| obj.is_a?(Hash) && obj[:Type] == :ObjStm}
			unless object_streams.empty?
				warn "PDF 1.5 Object streams found - they are not fully supported! attempting to extract objects."

				object_streams.each do |o|
					## un-encode (using the correct filter) the object streams
					PDFFilter.inflate_object o
					## extract objects from stream to top level arry @parsed
					@scanner = StringScanner.new o[:raw_stream_content]
					stream_data = _parse_
					id_array = []
					while stream_data[0].is_a? Fixnum
						id_array << stream_data.shift
						stream_data.shift
					end
					while id_array[0] && stream_data[0]
						stream_data[0] = {indirect_without_dictionary: stream_data[0]} unless stream_data[0].is_a?(Hash)
						stream_data[0][:indirect_reference_id] = id_array.shift
						stream_data[0][:indirect_generation_number] = 0
						@parsed << stream_data.shift
					end
				end
			end

			# Strings were unified, we can let them go..
			@strings_dictionary.clear

			# serialize_objects_and_references.catalog_pages

			# Benchmark.bm do |bm|
			# 	bm.report("serialize") {1000.times {serialize_objects_and_references} }
			# 	bm.report("serialize - old") {1000.times {old_serialize_objects_and_references} }
			# 	bm.report("catalog") {1000.times {catalog_pages} }
			# end

			serialize_objects_and_references.catalog_pages

			@info_object = @root_object[:Info] ? (@root_object[:Info][:referenced_object] || @root_object[:Info]) : false
			if @info_object && @info_object.is_a?(Hash)
				@parsed.delete @info_object
				CombinePDF::PDF::PRIVATE_HASH_KEYS.each {|key| @info_object.delete key}
				@info_object.each {|k, v| @info_object = v[:referenced_object] if v.is_a?(Hash) && v[:referenced_object]}
			else
				@info_object = {}
			end
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
			while @scanner.rest? do
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
				case
				##########################################
				## parse an Array
				##########################################
				when @scanner.scan(/\[/)
					out << _parse_
				##########################################
				## parse a Dictionary
				##########################################
				when @scanner.scan(/<</)
					data = _parse_
					obj = {}
					obj[data.shift] = data.shift while data[0]
					out << obj
				##########################################
				## return content of array or dictionary
				##########################################
				when @scanner.scan(/\]/), @scanner.scan(/>>/)
					return out
				##########################################
				## parse a Stream
				##########################################
				when @scanner.scan(/stream[\r\n]/)
					@scanner.pos += 1 if @scanner.peek(1) == "\n".freeze && @scanner.matched[-1] != "\n".freeze
					# the following was dicarded because some PDF files didn't have an EOL marker as required
					# str = @scanner.scan_until(/(\r\n|\r|\n)endstream/)
					# instead, a non-strict RegExp is used:
					str = @scanner.scan_until(/endstream/)
					# raise error if the stream doesn't end.
					raise "Parsing Error: PDF file error - a stream object wasn't properly colsed using 'endstream'!" unless str
					# need to remove end of stream
					if out.last.is_a? Hash
						# out.last[:raw_stream_content] = str[0...-10] #cuts only one EON char (\n or \r)
						out.last[:raw_stream_content] = unify_string str.sub(/(\r\n|\n|\r)?endstream\z/, "").force_encoding(Encoding::ASCII_8BIT)
					else
						warn "Stream not attached to dictionary!"
						out << str.sub(/(\r\n|\n|\r)?endstream\z/, "").force_encoding(Encoding::ASCII_8BIT)
					end
				##########################################
				## parse an Object after finished
				##########################################
				when str = @scanner.scan(/endobj/)
					#what to do when this is an object?
					if out.last.is_a? Hash
						out << out.pop.merge({indirect_generation_number: out.pop, indirect_reference_id: out.pop})
					else
						out << {indirect_without_dictionary: out.pop, indirect_generation_number: out.pop, indirect_reference_id: out.pop}
					end
					fresh = true
					# puts "!!!!!!!!! Error with :indirect_reference_id\n\nObject #{out.last}  :indirect_reference_id = #{out.last[:indirect_reference_id]}" unless out.last[:indirect_reference_id].is_a?(Fixnum)
				##########################################
				## parse a Hex String
				##########################################
				when str = @scanner.scan(/<[0-9a-fA-F]+>/)
					# warn "Found a hex string"
					out << unify_string([str[1..-2]].pack('H*').force_encoding(Encoding::ASCII_8BIT))
				##########################################
				## parse a Literal String
				##########################################
				when @scanner.scan(/\(/)
					# warn "Found a literal string"
					str = ''.force_encoding(Encoding::ASCII_8BIT)
					count = 1
					while count > 0 && @scanner.rest? do
						scn = @scanner.scan_until(/[\(\)]/)
						unless scn
							warn "Unknown error parsing string at #{@scanner.pos} for string: #{str}!"
							count = 0 # error
							next
						end

						str += scn.to_s
						seperator_count = 0
						seperator_count += 1 while str[-2-seperator_count] == "\\"

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
							when 110 #n
								str << 10 #new line
							when 114 #r
								str << 13 # CR
							when 116 #t
								str << 9 #tab
							when 98 #b
								str << 8
							when 102 #f
								str << 255
							when 48..57 #octal notation for byte?
								rep = rep.chr
								rep += str_bytes.shift.chr if str_bytes[0].between?(48,57)
								rep += str_bytes.shift.chr if str_bytes[0].between?(48,57) && ((rep + str_bytes[0].chr).to_i <= 255)
								str << rep.to_i
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
				##########################################
				## Parse a comment
				##########################################
				when str = @scanner.scan(/\%/)
					#is a comment, skip until new line
					loop do
						# break unless @scanner.scan(/[^\d\r\n]+/)
						break if @scanner.check(/([\d]+[\s]+[\d]+[\s]+obj[\n\r\s]+\<\<)|([\n\r]+)/) || @scanner.eos? # || @scanner.scan(/[^\d]+[\r\n]+/) ||
						@scanner.scan(/[^\d\r\n]+/) || @scanner.pos += 1
					end
					# puts "AFTER COMMENT: #{@scanner.peek 8}"
				##########################################
				## Parse a Name
				##########################################
				# old, probably working version: when str = @scanner.scan(/\/[\#\w\d\.\+\-\\\?\,]+/)
				# I don't know how to write the /[\x21-\x7e___subtract_certain_hex_values_here____]+/
				# all allowed regular caracters between ! and ~ : /[\x21-\x24\x26\x27\x2a-\x2e\x30-\x3b\x3d\x3f-\x5a\x5c\x5e-\x7a\x7c\x7e]+
				# all characters that aren't white space or special: /[^\x00\x09\x0a\x0c\x0d\x20\x28\x29\x3c\x3e\x5b\x5d\x7b\x7d\x2f\x25]+
			when str = @scanner.scan(/\/[^\x00\x09\x0a\x0c\x0d\x20\x28\x29\x3c\x3e\x5b\x5d\x7b\x7d\x2f\x25]*/)
					out << ( str[1..-1].gsub(/\#[0-9a-fA-F]{2}/) {|a| a[1..2].hex.chr } ).to_sym
				##########################################
				## Parse a Number
				##########################################
				when str = @scanner.scan(/[\+\-\.\d]+/)
					str.match(/\./) ? (out << str.to_f) : (out << str.to_i)
				##########################################
				## Parse an Object Reference
				##########################################
				when @scanner.scan(/R/)
					out << { is_reference_only: true, indirect_generation_number: out.pop, indirect_reference_id: out.pop}
					@references << out.last
				##########################################
				## Parse Bool - true and after false
				##########################################
				when @scanner.scan(/true/)
					out << true
				when @scanner.scan(/false/)
					out << false
				##########################################
				## Parse NULL - null
				##########################################
				when @scanner.scan(/null/)
					out << nil
				##########################################
				## XREF - check for encryption... anything else?
				##########################################
				when @scanner.scan(/xref/)
					##########
					## get root object to check for encryption
					@scanner.scan_until(/(trailer)|(\%EOF)/)
					fresh = true
					if @scanner.matched[-1] == 'r'
						if @scanner.skip_until(/<</)
							data = _parse_
							@root_object ||= {}
							@root_object[data.shift] = data.shift while data[0]
						end
						##########
						## skip untill end of segment, maked by %%EOF
						@scanner.skip_until(/\%\%EOF/)
						##########
						## If this was the last valid segment, ignore any trailing garbage
						## (issue #49 resolution)
						break unless @scanner.exist?(/\%\%EOF/)

					end

				when @scanner.scan(/[\s]+/)
					# Generally, do nothing
					nil
				when @scanner.scan(/obj[\s]*/)
					# Fix wkhtmltopdf PDF authoring issue - missing 'endobj' keywords
					unless fresh || (out[-4].nil? || out[-4].is_a?(Hash))
						keep = []
						keep << out.pop # .tap {|i| puts "#{i} is an ID"}
						keep << out.pop # .tap {|i| puts "#{i} is a REF"}

						if out.last.is_a? Hash
							out << out.pop.merge({indirect_generation_number: out.pop, indirect_reference_id: out.pop})
						else
							out << {indirect_without_dictionary: out.pop, indirect_generation_number: out.pop, indirect_reference_id: out.pop}
						end
						warn "'endobj' keyword was missing for Object ID: #{out.last[:indirect_reference_id]}, trying to auto-fix issue, but might fail."

						out << keep.pop
						out << keep.pop
					end
					fresh = false
				else
					# always advance
					# warn "Advancing for unknown reason... #{@scanner.string[@scanner.pos-4, 8]} ... #{@scanner.peek(4)}" unless @scanner.peek(1) =~ /[\s\n]/
					warn "Warning: parser advancing for unknown reason. Potential data-loss."
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
					catalogs = (@parsed.select {|obj| obj[:Type] == :Catalog}).last
				end
				@parsed.delete_if {|obj| obj[:Type] == :Catalog}
				@parsed << catalogs

				raise "Unknown error - parsed data doesn't contain a cataloged object!" unless catalogs
			end
			case
			when catalogs.is_a?(Array)
				catalogs.each {|c| catalog_pages(c, inheritance_hash ) unless c.nil?}
			when catalogs.is_a?(Hash)
				if catalogs[:is_reference_only]
					if catalogs[:referenced_object]
						catalog_pages(catalogs[:referenced_object], inheritance_hash)
					else
						warn "couldn't follow reference!!! #{catalogs} not found!"
					end
				else
					unless catalogs[:Type] == :Page
						raise "Optional Content PDF files aren't supported and their pages cannot be safely extracted." if catalogs[:AS] || catalogs[:OCProperties]
						inheritance_hash[:MediaBox] = catalogs[:MediaBox] if catalogs[:MediaBox]
						inheritance_hash[:CropBox] = catalogs[:CropBox] if catalogs[:CropBox]
						inheritance_hash[:Rotate] = catalogs[:Rotate] if catalogs[:Rotate]
						(inheritance_hash[:Resources] ||= {}).update( (catalogs[:Resources][:referenced_object] || catalogs[:Resources]), &self.class.method(:hash_update_proc_for_new) ) if catalogs[:Resources]
						(inheritance_hash[:ColorSpace] ||= {}).update( (catalogs[:ColorSpace][:referenced_object] || catalogs[:ColorSpace]), &self.class.method(:hash_update_proc_for_new) ) if catalogs[:ColorSpace]

						# inheritance_hash[:Order] = catalogs[:Order] if catalogs[:Order]
						# inheritance_hash[:OCProperties] = catalogs[:OCProperties] if catalogs[:OCProperties]
						# inheritance_hash[:AS] = catalogs[:AS] if catalogs[:AS]
					end

					case catalogs[:Type]
					when :Page

						catalogs[:MediaBox] ||= inheritance_hash[:MediaBox] if inheritance_hash[:MediaBox]
						catalogs[:CropBox] ||= inheritance_hash[:CropBox] if inheritance_hash[:CropBox]
						catalogs[:Rotate] ||= inheritance_hash[:Rotate] if inheritance_hash[:Rotate]
						(catalogs[:Resources] ||= {}).update( inheritance_hash[:Resources], &( self.class.method(:hash_update_proc_for_old) ) ) if inheritance_hash[:Resources]
						(catalogs[:ColorSpace] ||= {}).update( inheritance_hash[:ColorSpace], &( self.class.method(:hash_update_proc_for_old) ) ) if inheritance_hash[:ColorSpace]
						# catalogs[:Order] ||= inheritance_hash[:Order] if inheritance_hash[:Order]
						# catalogs[:AS] ||= inheritance_hash[:AS] if inheritance_hash[:AS]
						# catalogs[:OCProperties] ||= inheritance_hash[:OCProperties] if inheritance_hash[:OCProperties]


						# avoide references on MediaBox, CropBox and Rotate
						catalogs[:MediaBox] = catalogs[:MediaBox][:referenced_object][:indirect_without_dictionary] if catalogs[:MediaBox].is_a?(Hash) && catalogs[:MediaBox][:referenced_object].is_a?(Hash) && catalogs[:MediaBox][:referenced_object][:indirect_without_dictionary]
						catalogs[:CropBox] = catalogs[:CropBox][:referenced_object][:indirect_without_dictionary] if catalogs[:CropBox].is_a?(Hash) && catalogs[:CropBox][:referenced_object].is_a?(Hash) && catalogs[:CropBox][:referenced_object][:indirect_without_dictionary]
						catalogs[:Rotate] = catalogs[:Rotate][:referenced_object][:indirect_without_dictionary] if catalogs[:Rotate].is_a?(Hash) && catalogs[:Rotate][:referenced_object].is_a?(Hash) && catalogs[:Rotate][:referenced_object][:indirect_without_dictionary]

						catalogs.instance_eval {extend Page_Methods}
					when :Pages
						catalog_pages(catalogs[:Kids], inheritance_hash.dup ) unless catalogs[:Kids].nil?
					when :Catalog
						@forms_object.update( (catalogs[:AcroForm][:referenced_object] || catalogs[:AcroForm]), &self.class.method(:hash_update_proc_for_new) ) if catalogs[:AcroForm]
						@names_object.update( (catalogs[:Names][:referenced_object] || catalogs[:Names]), &self.class.method(:hash_update_proc_for_new) ) if catalogs[:Names]
						catalog_pages(catalogs[:Pages], inheritance_hash.dup ) unless catalogs[:Pages].nil?
					end
				end
			end
			self
		end

		# fails!
		def change_references_to_actual_values(hash_with_references = {})
			hash_with_references.each do |k,v|
				if v.is_a?(Hash) && v[:is_reference_only]
					hash_with_references[k] = get_refernced_object(v)
					hash_with_references[k] = hash_with_references[k][:indirect_without_dictionary] if hash_with_references[k].is_a?(Hash) && hash_with_references[k][:indirect_without_dictionary]
					warn "Couldn't connect all values from references - didn't find reference #{hash_with_references}!!!" if hash_with_references[k] == nil
					hash_with_references[k] = v unless hash_with_references[k]
				end
			end
			hash_with_references
		end

		def get_refernced_object(reference_hash = {})
			@parsed.each do |stored_object|
				return stored_object if ( stored_object.is_a?(Hash) &&
					reference_hash[:indirect_reference_id] == stored_object[:indirect_reference_id] &&
					reference_hash[:indirect_generation_number] == stored_object[:indirect_generation_number] )
			end
			warn "didn't find reference #{reference_hash}"
			nil
		end

		# @private
		# connects references and objects, according to their reference id's.
		#
		# should be moved to the parser's workflow.
		#
		def serialize_objects_and_references
			obj_dir = {}
			# create a dictionary for referenced objects (no value resolution at this point)
			@parsed.each {|o| obj_dir[ [ o.delete(:indirect_reference_id), o.delete(:indirect_generation_number) ] ] = o }
			# @parsed.each {|o| obj_dir[ [ o.[](:indirect_reference_id), o.[](:indirect_generation_number) ] ] = o }
			@references.each do |obj|
				obj[:referenced_object] = obj_dir[ [obj[:indirect_reference_id], obj[:indirect_generation_number] ]   ]
				warn "couldn't connect a reference!!! could be a null or removed (empty) object, Silent error!!!\n Object raising issue: #{obj.to_s}" unless obj[:referenced_object]
				obj.delete(:indirect_reference_id); obj.delete(:indirect_generation_number)
			end
			obj_dir.clear
			@references.clear
			self
		end

		# All Strings are one String
		def unify_string str
			@strings_dictionary[str] ||= str
		end

		# @private
		# this method reviews a Hash and updates it by merging Hash data,
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

		# # @private
		# # connects references and objects, according to their reference id's.
		# #
		# # should be moved to the parser's workflow.
		# #
		# def old_serialize_objects_and_references(object = nil)
		# 	objects_reference_hash = {}
		# 	# @parsed.each {|o| objects_reference_hash[ [ o.delete(:indirect_reference_id), o.delete(:indirect_generation_number) ] ] = o }
		# 	@parsed.each {|o| objects_reference_hash[ [ o.[](:indirect_reference_id), o.[](:indirect_generation_number) ] ] = o }
		# 	each_object(@parsed) do |obj|
		# 		if obj[:is_reference_only]
		# 			obj[:referenced_object] = objects_reference_hash[ [obj[:indirect_reference_id], obj[:indirect_generation_number] ]   ]
		# 			warn "couldn't connect a reference!!! could be a null or removed (empty) object, Silent error!!!\n Object raising issue: #{obj.to_s}" unless obj[:referenced_object]
		# 			# obj.delete(:indirect_reference_id); obj.delete(:indirect_generation_number)
		# 		end
		# 	end
		# 	self
		# end

		# # run block of code on evey PDF object (PDF objects are class Hash)
		# def each_object(object, limit_references = true, already_visited = {}, &block)
		# 	unless limit_references
		# 		already_visited[object.object_id] = true
		# 	end
		# 	case
		# 	when object.is_a?(Array)
		# 		object.each {|obj| each_object(obj, limit_references, already_visited, &block)}
		# 	when object.is_a?(Hash)
		# 		yield(object)
		# 		unless limit_references && object[:is_reference_only]
		# 			object.each do |k,v|
		# 				each_object(v, limit_references, already_visited, &block) unless already_visited[v.object_id]
		# 			end
		# 		end
		# 	end
		# end

	end
end
