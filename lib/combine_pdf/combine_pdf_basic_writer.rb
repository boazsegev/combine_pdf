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
		# length:: the length of the box. negative values will be computed from edge of page. defaults to 0 (end of page).
		# height:: the height of the box. negative values will be computed from edge of page. defaults to 0 (end of page).
		# text_align:: symbol for horizontal text alignment, can be ":center" (default), ":right", ":left"
		# text_valign:: symbol for vertical text alignment, can be ":center" (default), ":top", ":buttom"
		# font:: a Symbol representing one of the 14 standard fonts. defaults to ":Helvetica". the options are:
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
				length: 0,
				height: -1,
				text_align: :center,
				text_valign: :center,
				font: :Helvetica,
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
			options[:length] = mediabox[2] - options[:x] + options[:length] if options[:length] <= 0
			options[:height] = mediabox[3] - options[:y] + options[:height] if options[:height] <= 0
			# fit text in box, if requested
			font_size = options[:font_size]
			if options[:font_size] == :fit_text
				font_size = self.fit_text text, options[:font], options[:length], options[:height]
				font_size = options[:max_font_size] if options[:max_font_size] && font_size > options[:max_font_size]
			end


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
					box_stream << "#{options[:box_color].join(' ')} scn\n"
				end
				if options[:border_width].to_i > 0 && options[:border_color]
					box_stream << "#{options[:border_color].join(' ')} SCN\n"
				end
				# create the path
				radius = options[:box_radius]
				half_radius = radius.to_f / 2
				## set starting point
				box_stream << "#{options[:x] + radius} #{options[:y]} m\n" 
				## buttom and right corner - first line and first corner
				box_stream << "#{options[:x] + options[:length] - radius} #{options[:y]} l\n" #buttom
				if options[:box_radius] != 0 # make first corner, if not straight.
					box_stream << "#{options[:x] + options[:length] - half_radius} #{options[:y]} "
					box_stream << "#{options[:x] + options[:length]} #{options[:y] + half_radius} "
					box_stream << "#{options[:x] + options[:length]} #{options[:y] + radius} c\n"
				end
				## right and top-right corner
				box_stream << "#{options[:x] + options[:length]} #{options[:y] + options[:height] - radius} l\n"
				if options[:box_radius] != 0
					box_stream << "#{options[:x] + options[:length]} #{options[:y] + options[:height] - half_radius} "
					box_stream << "#{options[:x] + options[:length] - half_radius} #{options[:y] + options[:height]} "
					box_stream << "#{options[:x] + options[:length] - radius} #{options[:y] + options[:height]} c\n"
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
			if text.to_s != "" && font_size != 0 && (options[:font_color] || options[:stroke_color])
				# compute x and y position for text
				x = options[:x]
				y = options[:y]

				font_object = Fonts.get_font(options[:font])

				text_size = font_object.dimensions_of text, font_size

				if options[:text_align] == :center
					x = (options[:length] - text_size[0])/2 + x
				elsif options[:text_align] == :right
					x = (options[:length] - text_size[0]) + x
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
					text_stream << "#{options[:font_color].join(' ')} scn\n"
				end
				if options[:stroke_width].to_i > 0 && options[:stroke_color]
					text_stream << "#{options[:stroke_color].join(' ')} SCN\n"
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
				# format text object
				text_stream << "BT\n" # the Begine Text marker			
				text_stream << PDFOperations._format_name_to_pdf(set_font options[:font]) # Set font name
				text_stream << " #{font_size} Tf\n" # set font size and add font operator
				text_stream << "#{options[:font_color].join(' ')} rg\n" # sets the color state
				text_stream << "#{x} #{y} Td\n" # set location for text object
				text_stream << (  font_object.encode(text)  ) # insert the string in PDF format, after mapping to font glyphs
				text_stream << " Tj\n ET\n" # the Text object operator and the End Text marker
				# exit graphic state for text
				text_stream << "Q\nQ\nQ\n"
			end
			contents << text_stream

			self
		end
		def dimensions_of(text, font_name, size = 1000)
			Fonts.get_font(font_name).dimensions_of text, size
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
			metrics = Fonts.get_font(font).dimensions_of text, size
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
		# font:: a Symbol of one of the 14 Type 1 fonts, known as the standard 14 fonts:
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
			name = (SecureRandom.urlsafe_base64(9)).to_sym
			# get font object
			font_object = Fonts.get_font(font)
			# return false if the font wan't found in the library.
			return false unless font_object
			# add object to reasource
			resources[:Font][name] = font_object
			#return name
			name
		end
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
	end
	
end





