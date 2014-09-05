module CombinePDF
	class PDFWriter < Hash
		METRICS_DICTIONARY = {
			:"Times-Roman"			=>	TIMES_ROMAN_METRICS,
			:"Times-Bold"			=>	TIMES_BOLD_METRICS,
			:"Times-Italic"			=>	TIMES_ITALIC_METRICS,
			:"Times-BoldItalic"		=>	TIMES_BOLDITALIC_METRICS,
			:Helvetica				=>	HELVETICA_METRICS,
			:"Helvetica-Bold"		=>	HELVETICA_BOLD_METRICS,
			:"Helvetica-BoldOblique"=>	HELVETICA_BOLDOBLIQUE_METRICS,
			:"Helvetica-Oblique"	=>	HELVETICA_OBLIQUE_METRICS,
			:Courier				=>	COURIER_METRICS,
			:"Courier-Bold"			=>	COURIER_BOLD_METRICS,
			:"Courier-Oblique"		=>	COURIER_OBLIQUE_METRICS,
			:"Courier-BoldOblique"	=>	COURIER_BOLDOBLIQUE_METRICS,
			:Symbol					=>	SYMBOL_METRICS,
			:ZapfDingbats			=>	ZAPFDINGBATS_METRICS
		}
		def self.get_metrics(font_name)
			METRICS_DICTIONARY[font_name]
		end

		# This function calculates the dimentions of a string in a PDF.
		#
		# UNICODE SUPPORT IS MISSING!
		#
		# text:: String containing the text for which the demantion box will be calculated.
		# font_name:: the font name, from the 14 fonts possible. @see font
		# size:: the size of the text, as it will be applied in the PDF.
		def self.dimentions_of(text, font_name, size)
			metrics = METRICS_DICTIONARY[font_name]
			metrics_array = []
			# the following is only good for latin text - unicode support is missing!!!!
			text.each_char{|c|  metrics_array << (metrics.select {|k,v| v[:charcode] == c.bytes[0].ord}).to_a[0][1] }
			max_width = metrics_array.map {|m| m ? m[:wx] : 0} .max
			height = metrics_array.map {|m| m ? m[:boundingbox][3] : 0} .max
			height = height - (metrics_array.map {|m| m ? m[:boundingbox][1] : 0} ).min
			width = 0.0
			metrics_array.each do |m|
				if m
					width += m[:wx]
				else
					width += max_width
				end
			end
			[width.to_f/1000*size, height.to_f/1000*size]
		end
		
	end
end