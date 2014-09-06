# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################




module CombinePDF

	#:nodoc: all

	# <b>This doesn't work yet!</b>
	#
	# and also, even when it will work, UNICODE SUPPORT IS MISSING!
	#
	# in the future I wish to make a simple PDF page writer, that has only one functions - the text box.
	# Once the simple writer is ready (creates a text box in a self contained Page element),
	# I could add it to the << operators and add it as either a self contained page or as an overlay.
	# if all goes well, maybe I will also create an add_image function.
	#
	# The PDFWriter class is a subclass of Hash and represents a PDF Page object.
	#
	# Writing on this Page is done using the textbox function.
	#
	# Setting the page dimentions can be either at the new or using the mediabox method.
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
			self[:Type] = :Page
			self[:indirect_reference_id] = 0
			self[:Resources] = {}
			self[:Contents] = { is_reference_only: true , referenced_object: {indirect_reference_id: 0, raw_stream_content: ""} }
			self[:MediaBox] = mediabox
		end
		# accessor (getter) for the :MediaBox element of the page
		def mediabox
			self[:MediaBox]
		end
		# accessor (setter) for the :MediaBox element of the page
		# dimentions:: an Array consisting of four numbers (can be floats) setting the size of the media box.
		def mediabox=(dimentions = [0.0, 0.0, 612.0, 792.0])
			self[:MediaBox] = dimentions
		end

		# <b>INCOMPLETE</b>
		#
		# This function, when completed, will add a simple text box to the Page represented by the PDFWriter class.
		# This function takes two values:
		# text:: the text to potin the box.
		# properties:: a Hash of box properties.
		# the symbols and values in the properties Hash could be any or all of the following:
		# x:: the left position of the box.
		# y:: the BUTTOM position of the box.
		# length:: the length of the box.
		# height:: the height of the box.
		# text_align:: symbol for horizontal text alignment, can be ":center" (default), ":right", ":left"
		# text_valign:: symbol for vertical text alignment, can be ":center" (default), ":top", ":buttom"
		# font_name:: a Symbol representing one of the 14 standard fonts. defaults to ":Helvetica". the options are:
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
		# font_color:: text color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defaults to black.
		# stroke_color:: text stroke color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defounlts to nil (no stroke).
		# stroke_width:: text stroke width in PDF units. defaults to 0 (none).
		# box_color:: box fill color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defaults to nil (none).
		# border_color:: box border color in [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]"). defaults to nil (none).
		# border_width:: border width in PDF units. defaults to nil (none).
		# border_radius:: border radius in PDF units. defaults to 0 (no corner rounding).
		# opacity:: textbox opacity, a float between 0 (transparent) and 1 (opaque)
		# <b>now on testing mode, defaults are different! box defaults to gray with border and rounding.</b>
		def textbox(text, properties = {})
			options = {
				x: 0,
				y: 0,
				length: -1,
				height: -1,
				text_align: :center,
				text_valign: :center,
				font_name: :Helvetica,
				font_size: :fit_text,
				font_color: [0,0,0],
				stroke_color: nil,
				stroke_width: 0,
				box_color: [0.7,0.7,0.7], # for testing, should be nil
				border_color: [0.5,0.5,0.5], # for testing, should be nil
				border_width: 2, # for testing, should be nil
				border_radius: 5, # for testing, should be 0
				opacity: 1
			}
			options.update properties
			# reset the length and height to meaningful values, if negative
			options[:length] = mediabox[2] - options[:x] if options[:length] < 0
			options[:height] = mediabox[3] - options[:y] if options[:height] < 0
			# fit text in box, if requested
			font_size = options[:font_size]
			if options[:font_size] == :fit_text
				font_size = self.fit_text text, options[:font_name], options[:length], options[:height]
			end


			# create box stream
			box_stream = ""
			# set graphic state for box
			if options[:box_color] || (options[:stroke_color] && options[:border_color])
				# compute x and y position for text
				x = options[:x]
				y = options[:y]

				# set graphic state for the box
				box_stream << "q\nq\nq\n"
				box_graphic_state = graphic_state ca: options[:opacity], CA: options[:opacity], LW: options[:border_width], LC: 2, LJ:1,  LD: 0
				box_stream << "#{PDFOperations._object_to_pdf box_graphic_state} gs\n"
				box_stream << "DeviceRGB CS\nDeviceRGB cs\n"
				# create the path
				box_stream << "#{options[:x] + options[:border_radius]} #{options[:y]} m\n" # starting point
				box_stream << "#{options[:x] + options[:length] - options[:border_radius]} #{options[:y]} l\n" #buttom
				box_stream << "" if options[:border_radius] != 0
				# exit graphic state for the box
				box_stream << "Q\nQ\nQ\n"
			end
			#contents << box_stream

			# reset x,y by text alignment - x,y are calculated from the buttom left
			# each unit (1) is 1/72 Inch
			# create text stream
			text_stream = ""
			if text.to_s != "" && font_size != 0 && (options[:font_color] || options[:stroke_color])
				# compute x and y position for text
				x = options[:x]
				y = options[:y]

				text_size = dimentions_of text, options[:font_name], font_size
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
				text_stream << PDFOperations._format_name_to_pdf(font options[:font_name]) # Set font name
				text_stream << " #{font_size} Tf\n" # set font size and add font operator
				text_stream << "#{options[:font_color].join(' ')} rg\n" # sets the color state
				text_stream << "#{x} #{y} Td\n" # set location for text object
				text_stream << PDFOperations._format_string_to_pdf(text) # insert the string in PDF format
				text_stream << " Tj\n ET\n" # the Text object operator and the End Text marker
				# exit graphic state for text
				text_stream << "Q\nQ\nQ\n"
			end
			contents << text_stream

			self
		end

		protected

		# accessor (getter) for the :Resources element of the page
		def resources
			self[:Resources]
		end
		# accessor (getter) for the stream in the :Contents element of the page
		# after getting the string object, you can operate on it but not replace it (use << or other String methods).
		def contents
			self[:Contents][:referenced_object][:raw_stream_content]
		end
		# creates a font object and adds the font to the resources dictionary
		# returns the name of the font for the content stream.
		# font_name:: a Symbol of one of the 14 Type 1 fonts, known as the standard 14 fonts:
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
		def font(font_name = :Helvetica)
			# refuse any other fonts that arn't basic standard fonts
			allow_fonts = [ :"Times-Roman",
					:"Times-Bold",
					:"Times-Italic",
					:"Times-BoldItalic",
					:Helvetica,
					:"Helvetica-Bold",
					:"Helvetica-BoldOblique",
					:"Helvetica-Oblique",
					:Courier,
					:"Courier-Bold",
					:"Courier-Oblique",
					:"Courier-BoldOblique",
					:Symbol,
					:ZapfDingbats ]
			raise "add_font(font_name) accepts only one of the 14 standards fonts - wrong font_name!" unless allow_fonts.include? font_name
			# if the font exists, return it's name
			resources[:Font] ||= {}
			resources[:Font].each do |k,v|
				if v.is_a?(Hash) && v[:Type] == :Font && v[:BaseFont] == font_name
					return k
				end
			end
			# create font object
			font_object = { Type: :Font, Subtype: :Type1, BaseFont: font_name}
			# set a secure name for the font
			name = (SecureRandom.urlsafe_base64(9)).to_sym
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




# # textbox output example
# q
# q
# /GraphiStateName gs
# /DeviceRGB cs
# 0.867 0.867 0.867 scn
# 293.328 747.000 m
# 318.672 747.000 l
# 323.090 747.000 326.672 743.418 326.672 739.000 c
# 326.672 735.800 l
# 326.672 731.382 323.090 727.800 318.672 727.800 c
# 293.328 727.800 l
# 288.910 727.800 285.328 731.382 285.328 735.800 c
# 285.328 739.000 l
# 285.328 743.418 288.910 747.000 293.328 747.000 c
# h
# 293.328 64.200 m
# 318.672 64.200 l
# 323.090 64.200 326.672 60.618 326.672 56.200 c
# 326.672 53.000 l
# 326.672 48.582 323.090 45.000 318.672 45.000 c
# 293.328 45.000 l
# 288.910 45.000 285.328 48.582 285.328 53.000 c
# 285.328 56.200 l
# 285.328 60.618 288.910 64.200 293.328 64.200 c
# h
# f
# 0.000 0.000 0.000 scn
# /DeviceRGB CS
# 1.000 1.000 1.000 SCN

# 2 Tr
# 0.000 0.000 0.000 scn
# 0.000 0.000 0.000 SCN
# 1.000 1.000 1.000 SCN
# 0.000 0.000 0.000 scn
# 0.000 0.000 0.000 scn
# 0.000 0.000 0.000 SCN

# BT
# 291.776 733.3119999999999 Td
# /FontName 16 Tf
# [<2d2032202d>] TJ
# ET

# 1.000 1.000 1.000 SCN
# 0.000 0.000 0.000 scn
# 0.000 0.000 0.000 scn
# 0.000 0.000 0.000 SCN
# 1.000 1.000 1.000 SCN
# 0.000 0.000 0.000 scn
# 0.000 0.000 0.000 scn
# 0.000 0.000 0.000 SCN

# BT
# 291.776 50.512 Td
# /FontName 16 Tf
# [<2d2032202d>] TJ
# ET

# 1.000 1.000 1.000 SCN
# 0.000 0.000 0.000 scn

# 0 Tr
# Q
# Q






