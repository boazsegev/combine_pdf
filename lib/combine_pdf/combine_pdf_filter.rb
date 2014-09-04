# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################

module CombinePDF

	module PDFFilter
		module_function
		
		def deflate_object object = nil
			false
		end

		def inflate_object object = nil, filter = :none
			filter_array = object[:Filter]
			if filter_array.is_a?(Hash) && filter_array[:is_reference_only]
				filter_array = filter_array[:referenced_object]
			end
			if filter_array.is_a?(Symbol)
				filter_array = [filter_array]
			end
			filter_array = [] if filter_array.nil?
			params_array = object[:DecodeParms]
			if params_array.is_a?(Hash) && params_array[:is_reference_only]
				params_array = params_array[:referenced_object]
			end
			unless params_array.is_a?(Array)
				params_array = [params_array]
			end
			while filter_array[0]
				case filter_array[0]
				when :FlateDecode
					raise_unsupported_error params_array[0] unless params_array[0].nil?
					if params_array[0] && params_array[0][:Predictor].to_i > 1
						bits = params_array[0][:BitsPerComponent] || 8
						predictor = params_array[0][:Predictor].to_i
						columns = params_array[0][:Columns] || 1
						if (2..9).include? params_array[0][:Predictor].to_i
							####
							# prepare TIFF group
						elsif (10..15).include? params_array[0][:Predictor].to_i == 2
							####
							# prepare PNG group
						end
					else
						object[:raw_stream_content] = Zlib::Inflate.inflate object[:raw_stream_content]
						object[:Length] = object[:raw_stream_content].bytesize
					end
				when nil
					true
				else
					return false
				end
				params_array.shift
				filter_array.shift
			end
			object.delete(:Filter)
			true
		end
		def raise_unsupported_error (object = {})
			raise "Filter #{object} unsupported. couldn't deflate object"
		end

	end
	
end



