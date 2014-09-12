# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################




module CombinePDF

	#:nodoc: all

	# <b>not fully tested!</b>
	#
	# NO UNICODE SUPPORT!
	#
	# The PDFWriter class is a subclass of Hash and represents a PDF Page object.
	#
	# Writing on this Page is done using the textbox function.
	#
	# Setting the page dimensions can be either at the new or using the mediabox method.
	#
	# the rest of the methods are for internal use.
	#
	# Once the Page is completed (the last text box was added),
	# we can insert the page to a CombinePDF object.
	#
	# We can either insert the PDFWriter as a new page:
	#   pdf = CombinePDF.new
	#   new_page = PDFWriter.new
	#   new_page.textbox "some text"
	#   pdf << new_page
	#   pdf.save "file_with_new_page.pdf"
	# Or we can insert the PDFWriter as an overlay (stamp / watermark) over existing pages:
	#   pdf = CombinePDF.new
	#   new_page = PDFWriter.new "some_file.pdf"
	#   new_page.textbox "some text"
	#   pdf.pages.each {|page| page << new_page }
	#   pdf.save "stamped_file.pdf"
	class PDFWriter < Hash

		def initialize(mediabox = [0.0, 0.0, 612.0, 792.0])
			# indirect_reference_id, :indirect_generation_number
			@contents = ""
			@base_font_name = "Writer" + SecureRandom.urlsafe_base64(7) + "PDF"
			self[:Type] = :Page
			self[:indirect_reference_id] = 0
			self[:Resources] = {}
			self[:Contents] = { is_reference_only: true , referenced_object: {indirect_reference_id: 0, raw_stream_content: @contents} }
			self[:MediaBox] = mediabox
		end
		# accessor (getter) for the :MediaBox element of the page
		def mediabox
			self[:MediaBox]
		end
		# accessor (setter) for the :MediaBox element of the page
		# dimensions:: an Array consisting of four numbers (can be floats) setting the size of the media box.
		def mediabox=(dimensions = [0.0, 0.0, 612.0, 792.0])
			self[:MediaBox] = dimensions
		end

		# This method adds a simple text box to the Page represented by the PDFWriter class.
		# This function takes two values:
		# text:: the text to potin the box.
		# properties:: a Hash of box properties.
		# the symbols and values in the properties Hash could be any or all of the following:
		# x:: the left position of the box.
		# y:: the BUTTOM position of the box.
		# width:: the width/length of the box. negative values will be computed from edge of page. defaults to 0 (end of page).
		# height:: the height of the box. negative values will be computed from edge of page. defaults to 0 (end of page).
		# text_align:: symbol for horizontal text alignment, can be ":center" (default), ":right", ":left"
		# text_valign:: symbol for vertical text alignment, can be ":center" (default), ":top", ":buttom"
		# font:: a registered font name or an Array of names. defaults to ":Helvetica". The 14 standard fonts names are:
		# - :"Times-Roman"
		# - :"Times-Bold"
		# - :"Times-Italic"
		# - :"Times-BoldItalic"
		# - :Helvetica
		# - :"Helvetica-Bold"
		# - :"Helvetica-BoldOblique"
		# - :"Helvetica- Oblique"
		# - :Courier
		# - :"Courier-Bold"
		# - :"Courier-Oblique"
		# - :"Courier-BoldOblique"
		# - :Symbol
		# - :ZapfDingbats
		# font_size:: a Fixnum for the font size, or :fit_text to fit the text in the box. defaults to ":fit_text"
		# max_font_size:: if font_size is set to :fit_text, this will be the maximum font size. defaults to nil (no maximum)
		# font_color:: text color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defaults to black.
		# stroke_color:: text stroke color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defounlts to nil (no stroke).
		# stroke_width:: text stroke width in PDF units. defaults to 0 (none).
		# box_color:: box fill color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defaults to nil (none).
		# border_color:: box border color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defaults to nil (none).
		# border_width:: border width in PDF units. defaults to nil (none).
		# box_radius:: border radius in PDF units. defaults to 0 (no corner rounding).
		# opacity:: textbox opacity, a float between 0 (transparent) and 1 (opaque)
		def textbox(text, properties = {})
			options = {
				x: 0,
				y: 0,
				width: 0,
				height: -1,
				text_align: :center,
				text_valign: :center,
				font: nil,
				font_size: :fit_text,
				max_font_size: nil,
				font_color: [0,0,0],
				stroke_color: nil,
				stroke_width: 0,
				box_color: nil,
				border_color: nil,
				border_width: 0,
				box_radius: 0,
				opacity: 1
			}
			options.update properties
			# reset the length and height to meaningful values, if negative
			options[:width] = mediabox[2] - options[:x] + options[:width] if options[:width] <= 0
			options[:height] = mediabox[3] - options[:y] + options[:height] if options[:height] <= 0

			# create box stream
			box_stream = ""
			# set graphic state for box
			if options[:box_color] || (options[:border_width].to_i > 0 && options[:border_color])
				# compute x and y position for text
				x = options[:x]
				y = options[:y]

				# set graphic state for the box
				box_stream << "q\nq\nq\n"
				box_graphic_state = { ca: options[:opacity], CA: options[:opacity], LW: options[:border_width], LC: 0, LJ: 0,  LD: 0 }
				if options[:box_radius] != 0 # if the text box has rounded corners
					box_graphic_state[:LC], box_graphic_state[:LJ] =  2, 1
				end
				box_graphic_state = graphic_state box_graphic_state # adds the graphic state to Resources and gets the reference
				box_stream << "#{PDFOperations._object_to_pdf box_graphic_state} gs\n"
				box_stream << "DeviceRGB CS\nDeviceRGB cs\n"
				if options[:box_color]
					box_stream << "#{options[:box_color].join(' ')} rg\n"
				end
				if options[:border_width].to_i > 0 && options[:border_color]
					box_stream << "#{options[:border_color].join(' ')} RG\n"
				end
				# create the path
				radius = options[:box_radius]
				half_radius = (radius.to_f / 2).round 4
				## set starting point
				box_stream << "#{options[:x] + radius} #{options[:y]} m\n" 
				## buttom and right corner - first line and first corner
				box_stream << "#{options[:x] + options[:width] - radius} #{options[:y]} l\n" #buttom
				if options[:box_radius] != 0 # make first corner, if not straight.
					box_stream << "#{options[:x] + options[:width] - half_radius} #{options[:y]} "
					box_stream << "#{options[:x] + options[:width]} #{options[:y] + half_radius} "
					box_stream << "#{options[:x] + options[:width]} #{options[:y] + radius} c\n"
				end
				## right and top-right corner
				box_stream << "#{options[:x] + options[:width]} #{options[:y] + options[:height] - radius} l\n"
				if options[:box_radius] != 0
					box_stream << "#{options[:x] + options[:width]} #{options[:y] + options[:height] - half_radius} "
					box_stream << "#{options[:x] + options[:width] - half_radius} #{options[:y] + options[:height]} "
					box_stream << "#{options[:x] + options[:width] - radius} #{options[:y] + options[:height]} c\n"
				end
				## top and top-left corner
				box_stream << "#{options[:x] + radius} #{options[:y] + options[:height]} l\n"
				if options[:box_radius] != 0
					box_stream << "#{options[:x] + half_radius} #{options[:y] + options[:height]} "
					box_stream << "#{options[:x]} #{options[:y] + options[:height] - half_radius} "
					box_stream << "#{options[:x]} #{options[:y] + options[:height] - radius} c\n"
				end
				## left and buttom-left corner
				box_stream << "#{options[:x]} #{options[:y] + radius} l\n"
				if options[:box_radius] != 0
					box_stream << "#{options[:x]} #{options[:y] + half_radius} "
					box_stream << "#{options[:x] + half_radius} #{options[:y]} "
					box_stream << "#{options[:x] + radius} #{options[:y]} c\n"
				end
				# fill / stroke path
				box_stream << "h\n"
				if options[:box_color] && options[:border_width].to_i > 0 && options[:border_color]
					box_stream << "B\n"
				elsif options[:box_color] # fill if fill color is set
					box_stream << "f\n"
				elsif options[:border_width].to_i > 0 && options[:border_color] # stroke if border is set
					box_stream << "S\n"
				end

				# exit graphic state for the box
				box_stream << "Q\nQ\nQ\n"
			end
			contents << box_stream

			# reset x,y by text alignment - x,y are calculated from the buttom left
			# each unit (1) is 1/72 Inch
			# create text stream
			text_stream = ""
			if text.to_s != "" && options[:font_size] != 0 && (options[:font_color] || options[:stroke_color])
				# compute x and y position for text
				x = options[:x]
				y = options[:y]

				# set the fonts (fonts array, with :Helvetica as fallback).
				fonts = [*options[:font], :Helvetica]
				# fit text in box, if requested
				font_size = options[:font_size]
				if options[:font_size] == :fit_text
					font_size = self.fit_text text, fonts, options[:width], options[:height]
					font_size = options[:max_font_size] if options[:max_font_size] && font_size > options[:max_font_size]
				end

				text_size = dimensions_of text, fonts, font_size

				if options[:text_align] == :center
					x = (options[:width] - text_size[0])/2 + x
				elsif options[:text_align] == :right
					x = (options[:width] - text_size[0]) + x
				end
				if options[:text_valign] == :center
					y = (options[:height] - text_size[1])/2 + y
				elsif options[:text_valign] == :top
					y = (options[:height] - text_size[1]) + y
				end

				# set graphic state for text
				text_stream << "q\nq\nq\n"
				text_graphic_state = graphic_state({ca: options[:opacity], CA: options[:opacity], LW: options[:stroke_width].to_f, LC: 2, LJ: 1,  LD: 0})
				text_stream << "#{PDFOperations._object_to_pdf text_graphic_state} gs\n"
				text_stream << "DeviceRGB CS\nDeviceRGB cs\n"
				# set text render mode
				if options[:font_color]
					text_stream << "#{options[:font_color].join(' ')} rg\n"
				end
				if options[:stroke_width].to_i > 0 && options[:stroke_color]
					text_stream << "#{options[:stroke_color].join(' ')} RG\n"
					if options[:font_color]
						text_stream << "2 Tr\n"
					else
						final_stream << "1 Tr\n"
					end
				elsif options[:font_color]
					text_stream << "0 Tr\n"
				else
					text_stream << "3 Tr\n"
				end
				# format text object(s)
					# text_stream << "#{options[:font_color].join(' ')} rg\n" # sets the color state
				encode(text, fonts).each do |encoded|
					text_stream << "BT\n" # the Begine Text marker			
					text_stream << PDFOperations._format_name_to_pdf(set_font encoded[0]) # Set font name
					text_stream << " #{font_size} Tf\n" # set font size and add font operator
					text_stream << "#{x.round 4} #{y.round 4} Td\n" # set location for text object
					text_stream << (  encoded[1] ) # insert the encoded string to the stream
					text_stream << " Tj\n" # the Text object operator and the End Text marker
					text_stream << "ET\n" # the Text object operator and the End Text marker
					x += encoded[2]/1000*font_size #update text starting point
					y -= encoded[3]/1000*font_size #update text starting point
				end
				# exit graphic state for text
				text_stream << "Q\nQ\nQ\n"
			end
			contents << text_stream

			self
		end
		# gets the dimentions (width and height) of the text, as it will be printed in the PDF.
		#
		# text:: the text to measure
		# font:: a font name or an Array of font names. Font names should be registered fonts. The 14 standard fonts are pre regitered with the font library.
		# size:: the size of the font (defaults to 1000 points).
		def dimensions_of(text, fonts, size = 1000)
			Fonts.dimensions_of text, fonts, size
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
			metrics = Fonts.dimensions_of text, font, size
			if metrics[0] > length
				size_array << size * length/metrics[0]
			end
			if metrics[1] > height
				size_array << size * height/metrics[1]
			end
			size_array.min
		end


		protected

		# accessor (getter) for the :Resources element of the page
		def resources
			self[:Resources]
		end
		# accessor (getter) for the stream in the :Contents element of the page
		# after getting the string object, you can operate on it but not replace it (use << or other String methods).
		def contents
			@contents
		end
		# creates a font object and adds the font to the resources dictionary
		# returns the name of the font for the content stream.
		# font:: a Symbol of one of the fonts registered in the library, or:
		# - :"Times-Roman"
		# - :"Times-Bold"
		# - :"Times-Italic"
		# - :"Times-BoldItalic"
		# - :Helvetica
		# - :"Helvetica-Bold"
		# - :"Helvetica-BoldOblique"
		# - :"Helvetica- Oblique"
		# - :Courier
		# - :"Courier-Bold"
		# - :"Courier-Oblique"
		# - :"Courier-BoldOblique"
		# - :Symbol
		# - :ZapfDingbats
		def set_font(font = :Helvetica)
			# if the font exists, return it's name
			resources[:Font] ||= {}
			resources[:Font].each do |k,v|
				if v.is_a?(Fonts::Font) && v.name && v.name == font
					return k
				end
			end
			# set a secure name for the font
			name = (@base_font_name + (resources[:Font].length + 1).to_s).to_sym
			# get font object
			font_object = Fonts.get_font(font)
			# return false if the font wan't found in the library.
			return false unless font_object
			# add object to reasource
			resources[:Font][name] = font_object
			#return name
			name
		end
		# register or get a registered graphoc state dictionary.
		# the method returns the name of the graphos state, for use in a content stream.
		def graphic_state(graphic_state_dictionary = {})
			# if the graphic state exists, return it's name
			resources[:ExtGState] ||= {}
			resources[:ExtGState].each do |k,v|
				if v.is_a?(Hash) && v == graphic_state_dictionary
					return k
				end
			end
			# set graphic state type
			graphic_state_dictionary[:Type] = :ExtGState
			# set a secure name for the graphic state
			name = (SecureRandom.urlsafe_base64(9)).to_sym
			# add object to reasource
			resources[:ExtGState][name] = graphic_state_dictionary
			#return name
			name
		end

		# encodes the text in an array of [:font_name, <PDFHexString>] for use in textbox
		def encode text, fonts
			# text must be a unicode string and fonts must be an array.
			# this is an internal method, don't perform tests.
			fonts_array = []
			fonts.each do |name|
				f = Fonts.get_font name
				fonts_array << f if f
			end

			# before starting, we should reorder any RTL content in the string
			text = reorder_rtl_content text

			out = []
			text.chars.each do |c|
				fonts_array.each_index do |i|
					if fonts_array[i].cmap.nil? || (fonts_array[i].cmap && fonts_array[i].cmap[c])
						#add to array
						if out.last.nil? || out.last[0] != fonts[i]
							out.last[1] << ">" unless out.last.nil?
							out << [fonts[i], "<" , 0, 0] 
						end
						out.last[1] << ( fonts_array[i].cmap.nil? ? ( c.unpack("H*")[0] ) : (fonts_array[i].cmap[c]) )
						if fonts_array[i].metrics[c]
							out.last[2] += fonts_array[i].metrics[c][:wx].to_f
							out.last[3] += fonts_array[i].metrics[c][:wy].to_f
						end
						break
					end
				end
			end
			out.last[1] << ">" if out.last
			out
		end

		# a very primitive text reordering algorithm... I was lazy...
		# ...still, it works (I think).
		def reorder_rtl_content text
			rtl_characters = "\u05d0-\u05ea\u05f0-\u05f4\u0600-\u06ff\u0750-\u077f"
			return text unless text =~ /[#{rtl_characters}]/

			out = []
			scanner = StringScanner.new text
			until scanner.eos? do
				if scanner.scan /[#{rtl_characters}]/
					out.unshift scanner.matched
				end
				if scanner.scan /[^#{rtl_characters}]+/
					out.unshift scanner.matched
				end
			end
			out.join
		end
	end
	
end





