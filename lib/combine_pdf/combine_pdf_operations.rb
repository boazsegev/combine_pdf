module CombinePDF

	#:nodoc: all
	################################################################
	## These are common functions, used within the different classes
	## These functions aren't open to the public.
	################################################################

	#@private
	# lists the Hash keys used for PDF objects
	#
	# the CombinePDF library doesn't use special classes for its objects (PDFPage class, PDFStream class or anything like that).
	#
	# there is only one PDF class which represents the whole of the PDF file.
	#
	# this Hash lists the private Hash keys that the CombinePDF library uses to
	# differentiate between complex PDF objects.
	PRIVATE_HASH_KEYS = [:indirect_reference_id, :indirect_generation_number, :raw_stream_content, :is_reference_only, :referenced_object, :indirect_without_dictionary]
	#@private
	#:nodoc: all


	# This is an internal class. you don't need it.
	module PDFOperations
		module_function
		def inject_to_page page = {Type: :Page, MediaBox: [0,0,612.0,792.0], Resources: {}, Contents: []}, stream = nil, top = true
			# make sure both the page reciving the new data and the injected page are of the correct data type.
			return false unless page.is_a?(Hash) && stream.is_a?(Hash)

			# following the reference chain and assigning a pointer to the correct Resouces object.
			# (assignments of Strings, Arrays and Hashes are pointers in Ruby, unless the .dup method is called)
			original_resources = page[:Resources]
			if original_resources[:is_reference_only]
				original_resources = original_resources[:referenced_object]
				raise "Couldn't tap into resources dictionary, as it is a reference and isn't linked." unless original_resources
			end
			original_contents = page[:Contents]
			original_contents = [original_contents] unless original_contents.is_a? Array

			stream_resources = stream[:Resources]
			if stream_resources[:is_reference_only]
				stream_resources = stream_resources[:referenced_object]
				raise "Couldn't tap into resources dictionary, as it is a reference and isn't linked." unless stream_resources
			end
			stream_contents = stream[:Contents]
			stream_contents = [stream_contents] unless stream_contents.is_a? Array

			# collect keys as objects - this is to make sure that
			# we are working on the actual resource data, rather then references
			flatten_resources_dictionaries stream_resources
			flatten_resources_dictionaries original_resources

			# injecting each of the values in the injected Page
			stream_resources.each do |key, new_val|
				unless PRIVATE_HASH_KEYS.include? key # keep CombinePDF structual data intact.
					if original_resources[key].nil?
						original_resources[key] = new_val
					elsif original_resources[key].is_a?(Hash) && new_val.is_a?(Hash)
						new_val.update original_resources[key] # make sure the old values are respected
						original_resources[key].update new_val # transfer old and new values to the injected page
					end #Do nothing if array - ot is the PROC array, which is an issue
				end
			end
			original_resources[:ProcSet] = [:PDF, :Text, :ImageB, :ImageC, :ImageI] # this was recommended by the ISO. 32000-1:2008

			if top # if this is a stamp (overlay)
				page[:Contents] = original_contents
				page[:Contents].push *stream_contents
			else #if this was a watermark (underlay? would be lost if the page was scanned, as white might not be transparent)
				page[:Contents] = stream_contents
				page[:Contents].push *original_contents
			end

			page
		end
		# copy_and_secure_for_injection(page)
		# - page is a page in the pages array, i.e.
		#   pdf.pages[0]
		# takes a page object and:
		#
		# makes a deep copy of the page (Ruby defaults to pointers, so this will copy the memory).
		#
		# then it will rewrite the content stream with renamed resources, so as to avoid name conflicts.
		def copy_and_secure_for_injection(page)
			# copy page
			new_page = create_deep_copy page

			# initiate dictionary from old names to new names
			names_dictionary = {}

			# itirate through all keys that are name objects and give them new names (add to dic)
			# this should be done for every dictionary in :Resources
			# this is a few steps stage:

			# 1. get resources object
			resources = new_page[:Resources]
			if resources[:is_reference_only]
				resources = resources[:referenced_object]
				raise "Couldn't tap into resources dictionary, as it is a reference and isn't linked." unless resources
			end

			# 2. establich direct access to dictionaries and remove reference values
			flatten_resources_dictionaries resources

			# 3. travel every dictionary to pick up names (keys), change them and add them to the dictionary
			resources.each do |k,v|
				if v.is_a?(Hash)
					new_dictionary = {}
					v.each do |old_key, value|
						new_key = ("CombinePDF" + SecureRandom.urlsafe_base64(9)).to_sym
						names_dictionary[old_key] = new_key
						new_dictionary[new_key] = value
					end
					resources[k] = new_dictionary
				end
			end

			# now that we have replaced the names in the resources dictionaries,
			# it is time to replace the names inside the stream
			# we will need to make sure we have access to the stream injected
			# we will user PDFFilter.inflate_object
			(new_page[:Contents].is_a?(Array) ? new_page[:Contents] : [new_page[:Contents] ]).each do |c|
				stream = c[:referenced_object]
				PDFFilter.inflate_object stream
				names_dictionary.each do |old_key, new_key|
					stream[:raw_stream_content].gsub! _object_to_pdf(old_key), _object_to_pdf(new_key)  ##### PRAY(!) that the parsed datawill be correctly reproduced! 
				end
			end

			new_page
		end
		def flatten_resources_dictionaries(resources)
			resources.each do |k,v|
				if v.is_a?(Hash) && v[:is_reference_only]
					if v[:referenced_object]
						resources[k] = resources[k][:referenced_object].dup
						resources[k].delete(:indirect_reference_id)
						resources[k].delete(:indirect_generation_number)
					elsif v[:indirect_without_dictionary]
						resources[k] = resources[k][:indirect_without_dictionary]
					end
				end
			end
		end


		# Ruby normally assigns pointes.
		# noramlly:
		#   a = [1,2,3] # => [1,2,3]
		#   b = a # => [1,2,3]
		#   a << 4 # => [1,2,3,4]
		#   b # => [1,2,3,4]
		# This method makes sure that the memory is copied instead of a pointer assigned.
		# this works using recursion, so that arrays and hashes within arrays and hashes are also copied and not pointed to.
		# One needs to be careful of infinit loops using this function.
		def create_deep_copy object
			if object.is_a?(Array)
				return object.map { |e|  create_deep_copy e  }
			elsif object.is_a?(Hash)
				return {}.tap {|out|  object.each {|k,v| out[create_deep_copy(k)] = create_deep_copy(v) unless k == :Parent} }
			elsif object.is_a?(String)
				return object.dup
			else
				return object # objects that aren't Strings, Arrays or Hashes (such as Symbols and Fixnums) aren't pointers in Ruby and are always copied.
			end
		end
		# removes id and generation number values, for better comparrison
		# and avoiding object duplication
		# objects:: one or more objects in a PDF file/page.
		def remove_old_ids objects
			_each_object(objects) {|obj| obj.delete(:indirect_reference_id); obj.delete(:indirect_generation_number)}
		end
		def get_refernced_object(objects_array = [], reference_hash = {})
			objects_array.each do |stored_object|
				return stored_object if ( stored_object.is_a?(Hash) &&
					reference_hash[:indirect_reference_id] == stored_object[:indirect_reference_id] &&
					reference_hash[:indirect_generation_number] == stored_object[:indirect_generation_number] )
			end
			warn "didn't find reference #{reference_hash}"
			nil		
		end
		def change_references_to_actual_values(objects_array = [], hash_with_references = {})
			hash_with_references.each do |k,v|
				if v.is_a?(Hash) && v[:is_reference_only]
					hash_with_references[k] = PDFOperations.get_refernced_object( objects_array, v)
					hash_with_references[k] = hash_with_references[k][:indirect_without_dictionary] if hash_with_references[k].is_a?(Hash) && hash_with_references[k][:indirect_without_dictionary]
					warn "Couldn't connect all values from references - didn't find reference #{hash_with_references}!!!" if hash_with_references[k] == nil
					hash_with_references[k] = v unless hash_with_references[k]
				end
			end
			hash_with_references		
		end
		def change_connected_references_to_actual_values(hash_with_references = {})
			if hash_with_references.is_a?(Hash)
				hash_with_references.each do |k,v|
					if v.is_a?(Hash) && v[:is_reference_only]
						if v[:indirect_without_dictionary]
							hash_with_references[k] = v[:indirect_without_dictionary]
						elsif  v[:referenced_object]
							hash_with_references[k] = v[:referenced_object]
						else
							raise "Cannot change references to values, as they are disconnected!"
						end
					end
				end
				hash_with_references.each {|k, v| change_connected_references_to_actual_values(v) if v.is_a?(Hash) || v.is_a?(Array)}
			elsif hash_with_references.is_a?(Array)
				hash_with_references.each {|item| change_connected_references_to_actual_values(item) if item.is_a?(Hash) || item.is_a?(Array)}
			end
			hash_with_references		
		end
		def connect_references_and_actual_values(objects_array = [], hash_with_references = {})
			ret = true
			hash_with_references.each do |k,v|
				if v.is_a?(Hash) && v[:is_reference_only]
					ref_obj = PDFOperations.get_refernced_object( objects_array, v)
					hash_with_references[k] = ref_obj[:indirect_without_dictionary] if ref_obj.is_a?(Hash) && ref_obj[:indirect_without_dictionary]
					ret = false
				end
			end
			ret		
		end


		def _each_object(object, limit_references = true, first_call = true, &block)
			# #####################
			# ## v.1.2 needs optimazation
			# case
			# when object.is_a?(Array)
			# 	object.each {|obj| _each_object(obj, limit_references, &block)}
			# when object.is_a?(Hash)
			# 	yield(object)
			# 	object.each do |k,v|
			# 		unless (limit_references && k == :referenced_object)
			# 			unless k == :Parent
			# 				_each_object(v, limit_references, &block)
			# 			end
			# 		end
			# 	end
			# end
			#####################
			## v.2.1 needs optimazation
			## version 2.1 is slightly faster then v.1.2
			@already_visited = [] if first_call
			unless limit_references
				@already_visited << object.object_id
			end
			case
			when object.is_a?(Array)
				object.each {|obj| _each_object(obj, limit_references, false, &block)}
			when object.is_a?(Hash)
				yield(object)
				unless limit_references && object[:is_reference_only]
					object.each do |k,v|
						_each_object(v, limit_references, false, &block) unless @already_visited.include? v.object_id
					end
				end					
			end
		end



		# Formats an object into PDF format. This is used my the PDF object to format the PDF file and it is used in the secure injection which is still being developed.
		def _object_to_pdf object
			case
			when object.nil?
				return "null"
			when object.is_a?(String)
				return _format_string_to_pdf object
			when object.is_a?(Symbol)
				return _format_name_to_pdf object
			when object.is_a?(Array)
				return _format_array_to_pdf object
			when object.is_a?(Fixnum), object.is_a?(Float), object.is_a?(TrueClass), object.is_a?(FalseClass)
				return object.to_s + " "
			when object.is_a?(Hash)
				return _format_hash_to_pdf object
			else
				return ''
			end
		end

		def _format_string_to_pdf(object)
			if @string_output == :literal #if format is set to Literal
				#### can be better...
				replacement_hash = {
					"\x0A" => "\\n",
					"\x0D" => "\\r",
					"\x09" => "\\t",
					"\x08" => "\\b",
					"\xFF" => "\\f",
					"\x28" => "\\(",
					"\x29" => "\\)",
					"\x5C" => "\\\\"
				}
				32.times {|i| replacement_hash[i.chr] ||= "\\#{i}"}
				(256-128).times {|i| replacement_hash[(i + 127).chr] ||= "\\#{i+127}"}
				("(" + ([].tap {|out| object.bytes.each {|byte| replacement_hash[ byte.chr ] ? (replacement_hash[ byte.chr ].bytes.each {|b| out << b}) : out << byte } }).pack('C*') + ")").force_encoding(Encoding::ASCII_8BIT)
			else
				# A hexadecimal string shall be written as a sequence of hexadecimal digits (0–9 and either A–F or a–f)
				# encoded as ASCII characters and enclosed within angle brackets (using LESS-THAN SIGN (3Ch) and GREATER- THAN SIGN (3Eh)). 
				("<" + object.unpack('H*')[0] + ">").force_encoding(Encoding::ASCII_8BIT)
			end
		end
		def _format_name_to_pdf(object)
			# a name object is an atomic symbol uniquely defined by a sequence of ANY characters (8-bit values) except null (character code 0).
			# print name as a simple string. all characters between ~ and ! (except #) can be raw
			# the rest will have a number sign and their HEX equivalant
			# from the standard:
			# When writing a name in a PDF file, a SOLIDUS (2Fh) (/) shall be used to introduce a name. The SOLIDUS is not part of the name but is a prefix indicating that what follows is a sequence of characters representing the name in the PDF file and shall follow these rules:
			# a) A NUMBER SIGN (23h) (#) in a name shall be written by using its 2-digit hexadecimal code (23), preceded by the NUMBER SIGN.
			# b) Any character in a name that is a regular character (other than NUMBER SIGN) shall be written as itself or by using its 2-digit hexadecimal code, preceded by the NUMBER SIGN.
			# c) Any character that is not a regular character shall be written using its 2-digit hexadecimal code, preceded by the NUMBER SIGN only.
			# [0x00, 0x09, 0x0a, 0x0c, 0x0d, 0x20, 0x28, 0x29, 0x3c, 0x3e, 0x5b, 0x5d, 0x7b, 0x7d, 0x2f, 0x25]
			out = object.to_s.bytes.map do |b|
				case b
				when 0..15
					'#0' + b.to_s(16)
				when 15..32, 35, 37, 40, 41, 47, 60, 62, 91, 93, 123, 125, 127..256
					'#' + b.to_s(16)
				else
					b.chr
				end
			end
			"/" + out.join()
		end
		def _format_array_to_pdf(object)
			# An array shall be written as a sequence of objects enclosed in SQUARE BRACKETS (using LEFT SQUARE BRACKET (5Bh) and RIGHT SQUARE BRACKET (5Dh)).
			# EXAMPLE [549 3.14 false (Ralph) /SomeName]
			("[" + (object.collect {|item| _object_to_pdf(item)}).join(' ') + "]").force_encoding(Encoding::ASCII_8BIT)
			
		end

		def _format_hash_to_pdf(object)
			# if the object is only a reference:
			# special conditions apply, and there is only the setting of the reference (if needed) and output
			if object[:is_reference_only]
				#
				if object[:referenced_object] && object[:referenced_object].is_a?(Hash)
					object[:indirect_reference_id] = object[:referenced_object][:indirect_reference_id]
					object[:indirect_generation_number] = object[:referenced_object][:indirect_generation_number]
				end
				object[:indirect_reference_id] ||= 0
				object[:indirect_generation_number] ||= 0
				return "#{object[:indirect_reference_id].to_s} #{object[:indirect_generation_number].to_s} R".force_encoding(Encoding::ASCII_8BIT)
			end

			# if the object is indirect...
			out = []
			if object[:indirect_reference_id]
				object[:indirect_reference_id] ||= 0
				object[:indirect_generation_number] ||= 0
				out << "#{object[:indirect_reference_id].to_s} #{object[:indirect_generation_number].to_s} obj\n".force_encoding(Encoding::ASCII_8BIT)
				if object[:indirect_without_dictionary]
					out << _object_to_pdf(object[:indirect_without_dictionary])
					out << "\nendobj\n"
					return out.join().force_encoding(Encoding::ASCII_8BIT)
				end
			end
			# correct stream length, if the object is a stream.
			object[:Length] = object[:raw_stream_content].bytesize if object[:raw_stream_content]

			# if the object is not a simple object, it is a dictionary
			# A dictionary shall be written as a sequence of key-value pairs enclosed in double angle brackets (<<...>>)
			# (using LESS-THAN SIGNs (3Ch) and GREATER-THAN SIGNs (3Eh)).
			out << "<<\n".force_encoding(Encoding::ASCII_8BIT)
			object.each do |key, value|
				out << "#{_object_to_pdf key} #{_object_to_pdf value}\n".force_encoding(Encoding::ASCII_8BIT) unless PRIVATE_HASH_KEYS.include? key
			end
			out << ">>".force_encoding(Encoding::ASCII_8BIT)
			out << "\nstream\n#{object[:raw_stream_content]}\nendstream".force_encoding(Encoding::ASCII_8BIT) if object[:raw_stream_content]
			out << "\nendobj\n" if object[:indirect_reference_id]
			out.join().force_encoding(Encoding::ASCII_8BIT)
		end
	end
end

#########################################################
# this file is part of the CombinePDF library and the code
# is subject to the same license (GPLv3).
#########################################################
# PDF object types cross reference:
# Indirect objects, references, dictionaries and streams are Hash
# arrays are Array
# strings are String
# names are Symbols (String.to_sym)
# numbers are Fixnum or Float
# boolean are TrueClass or FalseClass
