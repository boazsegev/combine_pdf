# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################



module CombinePDF
	#:nodoc: all

	protected
	
	# @private
	# @!visibility private

	# This is an internal class. you don't need it.
	class PDFDecrypt
		include CombinePDF::Renderer

		# @!visibility private
		
		# make a new Decrypt object. requires:
		# objects:: an array containing the encrypted objects.
		# root_dictionary:: the root PDF dictionary, containing the Encrypt dictionary.
		def initialize objects=[], root_dictionary = {}
			@objects = objects
			@encryption_dictionary = actual_object(root_dictionary[:Encrypt])
			raise "Cannot decrypt an encrypted file without an encryption dictionary!" unless @encryption_dictionary
			@root_dictionary = actual_object(root_dictionary)
			@padding_key = [ 0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
							0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
							0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
							0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A ]
			@key_crypt_first_iv_store = nil
			@encryption_iv = nil
			change_references_to_actual_values @encryption_dictionary
		end

		# call this to start the decryption.
		def decrypt
			raise_encrypted_error @encryption_dictionary unless @encryption_dictionary[:Filter] == :Standard
			@key = set_general_key
			case actual_object(@encryption_dictionary[:V])
			when 1,2
				# raise_encrypted_error
				_perform_decrypt_proc_ @objects, self.method(:decrypt_RC4)
			when 4
				# raise unsupported error for now
				raise_encrypted_error
				# make sure CF is a Hash (as required by the PDF standard for this type of encryption).
				raise_encrypted_error unless actual_object(@encryption_dictionary[:CF]).is_a?(Hash)

				# do nothing if there is no data to decrypt except embeded files...?
				return true unless (actual_object(@encryption_dictionary[:CF]).values.select { |v| !v[:AuthEvent] || v[:AuthEvent] == :DocOpen } ).empty?

				# attempt to decrypt all strings?
				# attempt to decrypy all streams
				# attempt to decrypt all embeded files?

			else
				raise_encrypted_error
			end
			#rebuild stream lengths?
			@objects
		rescue => e
			raise_encrypted_error
		end

		protected

		def set_general_key(password = "")
			# 1) make sure the initial key is 32 byte long (if no password, uses padding).
			key = (password.bytes[0..32].to_a + @padding_key)[0..31].to_a.pack('C*').force_encoding(Encoding::ASCII_8BIT)
			# 2) add the value of the encryption dictionary’s O entry
			key << actual_object(@encryption_dictionary[:O]).to_s
			# 3) Convert the integer value of the P entry to a 32-bit unsigned binary number
			# and pass these bytes low-order byte first
			key << [actual_object(@encryption_dictionary[:P])].pack('i')
			# 4) Pass the first element of the file’s file identifier array
			# (the value of the ID entry in the document’s trailer dictionary
			key << actual_object(@root_dictionary[:ID])[0]
			# # 4(a) (Security handlers of revision 4 or greater)
			# # if document metadata is not being encrypted, add 4 bytes with the value 0xFFFFFFFF.
			if actual_object(@encryption_dictionary[:R]) >= 4
				unless actual_object(@encryption_dictionary)[:EncryptMetadata] == false #default is true and nil != false
					key << "\x00\x00\x00\x00"
				else
					key << "\xFF\xFF\xFF\xFF"
				end
			end
			# 5) pass everything as a MD5 hash
			key = Digest::MD5.digest(key)
			# 5(a) h) (Security handlers of revision 3 or greater) Do the following 50 times:
			# Take the output from the previous MD5 hash and
			# pass the first n bytes of the output as input into a new MD5 hash,
			# where n is the number of bytes of the encryption key as defined by the value of
			# the encryption dictionary’s Length entry.
			if actual_object(@encryption_dictionary[:R]) >= 3
				50.times do|i|
					key = Digest::MD5.digest(key[0...actual_object(@encryption_dictionary[:Length])])
				end
			end
			# 6) Set the encryption key to the first n bytes of the output from the final MD5 hash,
			# where n shall always be 5 for security handlers of revision 2 but,
			# for security handlers of revision 3 or greater,
			# shall depend on the value of the encryption dictionary’s Length entry.
			if actual_object(@encryption_dictionary[:R]) >= 3
				@key = key[0..(actual_object(@encryption_dictionary[:Length])/8)]
			else
				@key = key[0..4]
			end
			@key
		end
		def decrypt_none(encrypted, encrypted_id, encrypted_generation, encrypted_filter)
			"encrypted"
		end
		def decrypt_RC4(encrypted, encrypted_id, encrypted_generation, encrypted_filter)
			## start decryption using padding strings
			object_key = @key.dup
			object_key << [encrypted_id].pack('i')[0..2]
			object_key << [encrypted_generation].pack('i')[0..1]
			# (0..2).each { |e| object_key << (encrypted_id >> e*8 & 0xFF ) }
			# (0..1).each { |e| object_key << (encrypted_generation >> e*8 & 0xFF ) }
			key_length = object_key.length < 16 ? object_key.length : 16
			rc4 = ::RC4.new( Digest::MD5.digest(object_key)[(0...key_length)] )
			rc4.decrypt(encrypted)
		end
		def decrypt_AES(encrypted, encrypted_id, encrypted_generation, encrypted_filter)
			## extract encryption_iv if it wasn't extracted yet
			unless @encryption_iv
				@encryption_iv = encrypted[0..15].to_i
				#raise "Tryed decrypting using AES and couldn't extract iv" if @encryption_iv == 0
				@encryption_iv = 0.chr * 16
				#encrypted = encrypted[16..-1]
			end
			## start decryption using padding strings
			object_key = @key.dup
			(0..2).each { |e| object_key << (encrypted_id >> e*8 & 0xFF ) }
			(0..1).each { |e| object_key << (encrypted_generation >> e*8 & 0xFF ) }
			object_key << "sAlT"
			key_length = object_key.length < 16 ? object_key.length : 16
			cipher = OpenSSL::Cipher::Cipher.new("aes-#{object_key.length << 3}-cbc").decrypt
			cipher.padding = 0
			(cipher.update(encrypted) + cipher.final).unpack("C*")
		end

		protected

		def _perform_decrypt_proc_ (object, decrypt_proc, encrypted_id = nil, encrypted_generation = nil, encrypted_filter = nil)
			case
			when object.is_a?(Array)
				object.map! { |item| _perform_decrypt_proc_(item, decrypt_proc, encrypted_id, encrypted_generation, encrypted_filter) }
			when object.is_a?(Hash)
				encrypted_id ||= actual_object(object[:indirect_reference_id])
				encrypted_generation ||=  actual_object(object[:indirect_generation_number])
				encrypted_filter ||= actual_object(object[:Filter])
				if object[:raw_stream_content]
					stream_length = actual_value(object[:Length])
					actual_length = object[:raw_stream_content].bytesize
					if !stream_length # it's a required entry, but it might be missing
					    warn "PDF error, required stream length data is missing. Attempting to fix."
					    stream_length ||= actual_length 
					end
					
					length = [stream_length, actual_length].min
					
					object[:raw_stream_content] = decrypt_proc.call( (object[:raw_stream_content][0...length]), encrypted_id, encrypted_generation, encrypted_filter)
				end
				object.each {|k, v| object[k] = _perform_decrypt_proc_(v, decrypt_proc, encrypted_id, encrypted_generation, encrypted_filter) if k != :raw_stream_content && (v.is_a?(Hash) || v.is_a?(Array) || v.is_a?(String))} # assumes no decrypting is ever performed on keys
			when object.is_a?(String)
				return decrypt_proc.call(object, encrypted_id, encrypted_generation, encrypted_filter)
			else
				return object
			end
			
		end

		def raise_encrypted_error object = nil
			object ||= @encryption_dictionary.to_s.split(',').join("\n")
			warn "Data raising exception:\n #{object.to_s.split(',').join("\n")}"
			raise "File is encrypted - not supported."			
		end

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
			@objects.each do |stored_object|
				return stored_object if ( stored_object.is_a?(Hash) &&
					reference_hash[:indirect_reference_id] == stored_object[:indirect_reference_id] &&
					reference_hash[:indirect_generation_number] == stored_object[:indirect_generation_number] )
			end
			warn "didn't find reference #{reference_hash}"
			nil		
		end


		# # returns the PDF Object Hash holding the acutal data (if exists) or the original hash (if it wasn't a reference)
		# #
		# # works only AFTER references have been connected.
		# def get_referenced object
		# 	object[:referenced_object] || object
		# end

	end
	#####################################################
	## The following isn't my code!!!!
	## It is subject to a different license and copyright.
	## This was the code for the RC4 Gem,
	## ... I had a bad internet connection so I ended up
	## copying it from the web page I had in my cache.
	## This wonderful work was done by Caige Nichols.
	#####################################################
	# class RC4
	#   def initialize(str)
	#     begin
	#       raise SyntaxError, "RC4: Key supplied is blank"  if str.eql?('')

	#       @q1, @q2 = 0, 0
	#       @key = []
	#       str.each_byte { |elem| @key << elem } while @key.size < 256
	#       @key.slice!(256..@key.size-1) if @key.size >= 256
	#       @s = (0..255).to_a
	#       j = 0
	#       0.upto(255) do |i|
	#         j = (j + @s[i] + @key[i] ) % 256
	#         @s[i], @s[j] = @s[j], @s[i]
	#       end
	#     end
	#   end

	#   def encrypt!(text)
	#     process text
	#   end

	#   def encrypt(text)
	#     process text.dup
	#   end

	#   alias_method :decrypt, :encrypt

	#   private

	#   def process(text)
	#     text.unpack("C*").map { |c| c ^ round }.pack("C*")
	#   end

	#   def round
	#     @q1 = (@q1 + 1) % 256
	#     @q2 = (@q2 + @s[@q1]) % 256
	#     @s[@q1], @s[@q2] = @s[@q2], @s[@q1]
	#     @s[(@s[@q1]+@s[@q2]) % 256]
	#   end
	# end

end
