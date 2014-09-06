module CombinePDF
	class PDFWriter < Hash
		# This function calculates the dimentions of a string in a PDF.
		#
		# UNICODE SUPPORT IS MISSING!
		#
		# text:: String containing the text for which the demantion box will be calculated.
		# font:: the font name, from the 14 fonts possible. @see font
		# size:: the size of the text, as it will be applied in the PDF.
		def dimentions_of(text, font, size = 1000)
			metrics = METRICS_DICTIONARY[font]
			metrics_array = []
			# the following is only good for latin text - unicode support is missing!!!!
			text.each_char do |c|
				metrics_mappings = metrics.select {|k,v| v[:charcode] == c.bytes[0].ord}
				######
				# need to add unicode support
				# this is a lousy patch that puts the bounds of @ inside...
				metrics_mappings = metrics.select {|k,v| v[:charcode] == "@".ord} if metrics_mappings.empty?
				metrics_array << metrics_mappings.to_a[0][1]
			end
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

		protected

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

		# this method returns the size for which the text fits the requested metrices
		# the size is type Float and is rather exact
		# if the text cannot fit such a small place, returns zero (0).
		# maximum font size possible is set to 100,000 - which should be big enough for anything
		# text:: the text to fit
		# font:: the font name. @see font
		# length:: the length to fit
		# height:: the height to fit (optional - normally length is the issue)
		def fit_text(text, font, length, height = 10000000)
			size = 100000
			size_array = [size]
			metrics = dimentions_of text, font, size
			if metrics[0] > length
				size_array << size * length/metrics[0]
			end
			if metrics[1] > height
				size_array << size * height/metrics[1]
			end
			size_array.min
		end
	end
end