module CombinePDF

	################################################################
	## These are common functions, used within the different classes
	## These functions aren't open to the public.
	################################################################


	# This is an internal module used to render ruby objects into pdf objects.
	module Renderer

		# @!visibility private

		protected


		# Formats an object into PDF format. This is used my the PDF object to format the PDF file and it is used in the secure injection which is still being developed.
		def object_to_pdf object
			case
			when object.nil?
				return "null"
			when object.is_a?(String)
				return format_string_to_pdf object
			when object.is_a?(Symbol)
				return format_name_to_pdf object
			when object.is_a?(Array)
				return format_array_to_pdf object
			when object.is_a?(Fixnum), object.is_a?(Float), object.is_a?(TrueClass), object.is_a?(FalseClass)
				return object.to_s + " "
			when object.is_a?(Hash)
				return format_hash_to_pdf object
			else
				return ''
			end
		end

		def format_string_to_pdf(object)
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
		def format_name_to_pdf(object)
			# a name object is an atomic symbol uniquely defined by a sequence of ANY characters (8-bit values) except null (character code 0).
			# print name as a simple string. all characters between ~ and ! (except #) can be raw
			# the rest will have a number sign and their HEX equivalant
			# from the standard:
			# When writing a name in a PDF file, a SOLIDUS (2Fh) (/) shall be used to introduce a name. The SOLIDUS is not part of the name but is a prefix indicating that what follows is a sequence of characters representing the name in the PDF file and shall follow these rules:
			# a) A NUMBER SIGN (23h) (#) in a name shall be written by using its 2-digit hexadecimal code (23), preceded by the NUMBER SIGN.
			# b) Any character in a name that is a regular character (other than NUMBER SIGN) shall be written as itself or by using its 2-digit hexadecimal code, preceded by the NUMBER SIGN.
			# c) Any character that is not a regular character shall be written using its 2-digit hexadecimal code, preceded by the NUMBER SIGN only.
			# [0x00, 0x09, 0x0a, 0x0c, 0x0d, 0x20, 0x28, 0x29, 0x3c, 0x3e, 0x5b, 0x5d, 0x7b, 0x7d, 0x2f, 0x25]
			out = object.to_s.bytes.to_a.map do |b|
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
		def format_array_to_pdf(object)
			# An array shall be written as a sequence of objects enclosed in SQUARE BRACKETS (using LEFT SQUARE BRACKET (5Bh) and RIGHT SQUARE BRACKET (5Dh)).
			# EXAMPLE [549 3.14 false (Ralph) /SomeName]
			("[" + (object.collect {|item| object_to_pdf(item)}).join(' ') + "]").force_encoding(Encoding::ASCII_8BIT)
			
		end

		def format_hash_to_pdf(object)
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
					out << object_to_pdf(object[:indirect_without_dictionary])
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
				out << "#{object_to_pdf key} #{object_to_pdf value}\n".force_encoding(Encoding::ASCII_8BIT) unless PDF::PRIVATE_HASH_KEYS.include? key
			end
			out << ">>".force_encoding(Encoding::ASCII_8BIT)
			out << "\nstream\n#{object[:raw_stream_content]}\nendstream".force_encoding(Encoding::ASCII_8BIT) if object[:raw_stream_content]
			out << "\nendobj\n" if object[:indirect_reference_id]
			out.join().force_encoding(Encoding::ASCII_8BIT)
		end

		def actual_object obj
			obj.is_a?(Hash) ? (obj[:referenced_object] || obj) : obj
		end
	end
end

#########################################################
# this file is part of the CombinePDF library and the code
# is subject to the same license (MIT).
#########################################################
# PDF object types cross reference:
# Indirect objects, references, dictionaries and streams are Hash
# arrays are Array
# strings are String
# names are Symbols (String.to_sym)
# numbers are Fixnum or Float
# boolean are TrueClass or FalseClass
