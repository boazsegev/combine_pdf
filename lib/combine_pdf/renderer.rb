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
    def object_to_pdf(object)
      if object.nil?
        return 'null'
      elsif object.is_a?(String)
        return format_string_to_pdf object
      elsif object.is_a?(Symbol)
        return format_name_to_pdf object
      elsif object.is_a?(Array)
        return format_array_to_pdf object
      elsif object.is_a?(Integer) || object.is_a?(TrueClass) || object.is_a?(FalseClass)
        return object.to_s
      elsif object.is_a?(Numeric) # Float or other non-integer
        return sprintf('%f', object)
      elsif object.is_a?(Hash)
        return format_hash_to_pdf object
      else
        return ''
      end
    end

    STRING_REPLACEMENT_ARRAY = []
    256.times {|i| STRING_REPLACEMENT_ARRAY[i] = [i]}
    8.times { |i| STRING_REPLACEMENT_ARRAY[i] =  "\\00#{i.to_s(8)}".bytes.to_a }
    24.times { |i| STRING_REPLACEMENT_ARRAY[i + 7] =  "\\0#{i.to_s(8)}".bytes.to_a }
    (256 - 127).times { |i| STRING_REPLACEMENT_ARRAY[(i + 127)] ||= "\\#{(i + 127).to_s(8)}".bytes.to_a }
    STRING_REPLACEMENT_ARRAY[0x0A] = '\\n'.bytes.to_a
    STRING_REPLACEMENT_ARRAY[0x0D] = '\\r'.bytes.to_a
    STRING_REPLACEMENT_ARRAY[0x09] = '\\t'.bytes.to_a
    STRING_REPLACEMENT_ARRAY[0x08] = '\\b'.bytes.to_a
    STRING_REPLACEMENT_ARRAY[0x0C] = '\\f'.bytes.to_a # form-feed (\f) == 0x0C
    STRING_REPLACEMENT_ARRAY[0x28] = '\\('.bytes.to_a
    STRING_REPLACEMENT_ARRAY[0x29] = '\\)'.bytes.to_a
    STRING_REPLACEMENT_ARRAY[0x5C] = '\\\\'.bytes.to_a

    def format_string_to_pdf(object)
      obj_bytes = object.bytes.to_a
      # object.force_encoding(Encoding::ASCII_8BIT)
      if object.length == 0 || obj_bytes.min <= 31 || obj_bytes.max >= 127 # || (obj_bytes[0] != 68  object.match(/[^D\:\d\+\-Z\']/))
        # A hexadecimal string shall be written as a sequence of hexadecimal digits (0–9 and either A–F or a–f)
        # encoded as ASCII characters and enclosed within angle brackets (using LESS-THAN SIGN (3Ch) and GREATER- THAN SIGN (3Eh)).
        "<#{object.unpack('H*')[0]}>".force_encoding(Encoding::ASCII_8BIT)
      else
        # a good fit for a Literal String or the string is a date (MUST be literal)
        ('(' + ([].tap { |out| obj_bytes.each { |byte| out.concat(STRING_REPLACEMENT_ARRAY[byte]) } } ).pack('C*') + ')').force_encoding(Encoding::ASCII_8BIT)
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
      '/' + out.join
    end

    def format_array_to_pdf(object)
      # An array shall be written as a sequence of objects enclosed in SQUARE BRACKETS (using LEFT SQUARE BRACKET (5Bh) and RIGHT SQUARE BRACKET (5Dh)).
      # EXAMPLE [549 3.14 false (Ralph) /SomeName]
      ('[' + (object.collect { |item| object_to_pdf(item) }).join(' ') + ']').force_encoding(Encoding::ASCII_8BIT)
    end

    EMPTY_PAGE_CONTENT_STREAM = {is_reference_only: true, referenced_object: { indirect_reference_id: 0, raw_stream_content: '' }}

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
        return "#{object[:indirect_reference_id]} #{object[:indirect_generation_number]} R".force_encoding(Encoding::ASCII_8BIT)
      end

      # if the object is indirect...
      out = []
      if object[:indirect_reference_id]
        object[:indirect_reference_id] ||= 0
        object[:indirect_generation_number] ||= 0
        out << "#{object[:indirect_reference_id]} #{object[:indirect_generation_number]} obj\n".force_encoding(Encoding::ASCII_8BIT)
        if object[:indirect_without_dictionary]
          out << object_to_pdf(object[:indirect_without_dictionary])
          out << "\nendobj\n"
          return out.join.force_encoding(Encoding::ASCII_8BIT)
        end
      end
      # remove extra page references.
      object[:Contents].delete(EMPTY_PAGE_CONTENT_STREAM) if object[:Type] == :Page && object[:Contents].is_a?(Array)
      # correct stream length, if the object is a stream.
      object[:Length] = object[:raw_stream_content].bytesize if object[:raw_stream_content]

      # if the object is not a simple object, it is a dictionary
      # A dictionary shall be written as a sequence of key-value pairs enclosed in double angle brackets (<<...>>)
      # (using LESS-THAN SIGNs (3Ch) and GREATER-THAN SIGNs (3Eh)).
      out << "<<\n".force_encoding(Encoding::ASCII_8BIT)
      object.each do |key, value|
        out << "#{object_to_pdf key} #{object_to_pdf value}\n".force_encoding(Encoding::ASCII_8BIT) unless PDF::PRIVATE_HASH_KEYS.include? key
      end
      object.delete :Length
      out << '>>'.force_encoding(Encoding::ASCII_8BIT)
      out << "\nstream\n#{object[:raw_stream_content]}\nendstream".force_encoding(Encoding::ASCII_8BIT) if object[:raw_stream_content]
      out << "\nendobj\n" if object[:indirect_reference_id]
      out.join.force_encoding(Encoding::ASCII_8BIT)
    end

    def actual_object(obj)
      obj.is_a?(Hash) ? (obj[:referenced_object] || obj) : obj
    end

    def actual_value(obj)
      return obj unless obj.is_a?(Hash)
      obj = obj[:referenced_object] || obj
      obj[:indirect_without_dictionary] || obj
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
    def create_deep_copy(object)
      if object.is_a?(Array)
        return object.map { |e| create_deep_copy e }
      elsif object.is_a?(Hash)
        return {}.tap { |out| object.each { |k, v| out[create_deep_copy(k)] = create_deep_copy(v) unless k == :Parent } }
      elsif object.is_a?(String)
        return object.dup
      else
        return object # objects that aren't Strings, Arrays or Hashes (such as Symbols and Integers) won't be edited inplace.
      end
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
# numbers are Integers or Float
# boolean are TrueClass or FalseClass
