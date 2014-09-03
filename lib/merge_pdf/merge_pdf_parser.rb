# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the MergePDF library and the code
## is subject to the same license.
########################################################
module MergePDF

	########################################################
	## This is the Parser class.
	## It takes PDF data and parses it, returning an array
	## of data.
	## That array can be used to initialize a PDF object.
	## The Parser class doesn't involve itself with the
	## file version.
	########################################################

	class PDFParser
		# LITERAL_STRING_REPLACEMENT_HASH = {
		# 	110 => 10, # "\\n".bytes = [92, 110]  "\n".ord = 10
		# 	114 => 13, #r
		# 	116 => 9, #t
		# 	98 => 8, #b 
		# 	102 => 255, #f
		# 	40 => 40, #(
		# 	41 => 41, #)
		# 	92 => 92 #\
		# 	}
		attr_reader :parsed, :version, :info_object, :root_object
		def initialize (string)
			raise TypeError, "couldn't parse and data, expecting type String" unless string.is_a? String
			@string_to_parse = string.force_encoding(Encoding::ASCII_8BIT)
			@literal_strings = []
			@hex_strings = []
			@streams = []
			@parsed = []
			@root_object = {}
			@info_object = {}
			@version = nil
			@scanner = nil
		end

		def parse
			return @parsed unless @parsed.empty?
			@scanner = StringScanner.new @string_to_parse
			@scanner.pos = 0
			if @scanner.scan /\%PDF\-[\d\-\.]+/
				@version = @scanner.matched.scan(/[\d\.]+/)[0].to_f
			end

			warn "Starting to parse PDF data."
			@parsed = _parse_

			if @root_object == {}
				xref_streams = @parsed.select {|obj| obj.is_a?(Hash) && obj[:Type] == :XRef}
				xref_streams.each do |xref_dictionary|
					@root_object.merge! xref_dictionary
				end
			end
			raise "root is unknown - cannot determine if file is Encrypted" if @root_object == {}
			warn "Injecting actual values into root object: #{@root_object}."
			PDFOperations.change_references_to_actual_values @parsed, @root_object

			if @root_object[:Encrypt]
				warn "PDF is Encrypted! Attempting to unencrypt - not yet fully supported."
				decryptor = PDFDecrypt.new @parsed, @root_object
				decryptor.decrypt
				#do we really need to apply to @parsed? No, there is no need.
			end
			if @version >= 1.5 # code placement for object streams
				## search for objects streams
				object_streams = @parsed.select {|obj| obj.is_a?(Hash) && obj[:Type] == :ObjStm}
				unless object_streams.empty?
					warn "PDF 1.5 Object streams found - they are not fully supported! attempting to extract objects."
					
					object_streams.each do |o|
						warn "Attempting #{o.select {|k,v| k != :raw_stream_content}}"
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
						while stream_data[0].is_a? Hash
							stream_data[0][:indirect_reference_id] = id_array.shift
							stream_data[0][:indirect_generation_number] = 0
							@parsed << stream_data.shift
						end
					end
					# ## remove object streams
					@parsed.reject! {|obj| object_streams << obj if obj.is_a?(Hash) && obj[:Type] == :ObjStm}
					# ## remove XREF dictionaries
					@parsed.reject! {|obj| object_streams << obj if obj.is_a?(Hash) && obj[:Type] == :XRef}
				end
			end
			PDFOperations.change_references_to_actual_values @parsed, @root_object
			@info_object = @root_object[:Info]
			if @info_object && @info_object.is_a?(Hash)
				PRIVATE_HASH_KEYS.each {|key| @info_object.delete key}
			else
				@info_object = {}
			end
			warn "setting parsed collection and returning collection."
			@parsed
		end

		protected
		
		def _parse_
			out = []
			str = ''
			# warn "Scaning for objects, starting at #{@scanner.pos}: #{@scanner.peek(10)}"
			while @scanner.rest? do
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
				when @scanner.scan(/stream[\r]?[\n]/)
					str = @scanner.scan_until(/endstream/)
					# need to remove end of stream
					if out.last.is_a? Hash
						out.last[:raw_stream_content] = str[0...-10] #cuts only one EON char (\n or \r)
						# out.last[:raw_stream_content] = str.gsub(/[\n\r]?[\n\r]?endstream/, "")
					else
						warn "Stream not attached to dictionary!"
						out << str[0...-10].force_encoding(Encoding::ASCII_8BIT)
					end
				##########################################
				## parse an Object after finished
				##########################################
				when str = @scanner.scan(/endobj/)
					# warn "Proccessing Object"
					#what to do when this is an object?
					if out.last.is_a? Hash
						out << out.pop.merge({indirect_generation_number: out.pop, indirect_reference_id: out.pop})
					else
						out << {indirect_without_dictionary: out.pop, indirect_generation_number: out.pop, indirect_reference_id: out.pop}
					end
				##########################################
				## parse a Hex String
				##########################################
				when str = @scanner.scan(/<[0-9a-f]+>/)
					# warn "Found a hex string"
					out << [str[1..-2]].pack('H*')
				##########################################
				## parse a Literal String
				##########################################
				when @scanner.scan(/\(/)
					# warn "Found a literal string"
					str = ''
					count = 1
					while count > 0 && @scanner.rest? do
						str += @scanner.scan_until(/[\(\)]/).to_s
						seperator_count = 0
						seperator_count += 1 while str[-2-seperator_count] == "\\"

						case str[-1]
						when '('
							## The following solution fails when (string ends with this sign: \\)

							count += 1 unless seperator_count.odd?
						when ')'
							count -= 1 unless seperator_count.odd?
						else
							warn "Unknown error parsing string at #{@scanner.pos}!"
							cout = 0 # error
						end
					end
					# The PDF formatted string is: str[0..-2]
					# now staring to convert to regular string
					str_bytes = str[0..-2].bytes
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
							when 48..57 #decimal notation for byte?
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
					out << str.pack('C*')
				##########################################
				## Parse a comment
				##########################################
				when str = @scanner.scan(/\%/)
					#is a comment, skip until new line
					@scanner.skip_until /[\n\r]+/
				##########################################
				## Parse a Name
				##########################################
				# old, probably working version: when str = @scanner.scan(/\/[\#\w\d\.\+\-\\\?\,]+/)
				# I don't know how to write the /[\x21-\x7e___subtract_certain_hex_values_here____]+/
				# all allowed regular caracters between ! and ~ : /[\x21-\x24\x26\x27\x2a-\x2e\x30-\x3b\x3d\x3f-\x5a\x5c\x5e-\x7a\x7c\x7e]+
				# all characters that aren't white space or special: /[^\x00\x09\x0a\x0c\x0d\x20\x28\x29\x3c\x3e\x5b\x5d\x7b\x7d\x2f\x25]+
			when str = @scanner.scan(/\/[^\x00\x09\x0a\x0c\x0d\x20\x28\x29\x3c\x3e\x5b\x5d\x7b\x7d\x2f\x25]+/)
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

					if @scanner.matched[-1] == 'r'
						if @scanner.skip_until(/<</)
							data = _parse_
							@root_object = {}
							@root_object[data.shift] = data.shift while data[0]						
						end
						##########
						## skip untill end of segment, maked by %%EOF
						@scanner.skip_until(/\%\%EOF/)
					end
					
				when @scanner.scan(/[\s]+/) , @scanner.scan(/obj[\s]*/)
					# do nothing
					# warn "White Space, do nothing"
					nil
				else
					# always advance 
					# warn "Advnacing for unknown reason..."
					@scanner.pos = @scanner.pos + 1
				end
			end
			out
		end
	end
end