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
	# Writing on this Page is done using the text_box function.
	#
	# Setting the page dimentions can be either at the new or using the media_box method.
	#
	# the rest of the methods are for internal use.
	#
	# Once the Page is completed (the last text box was added),
	# we can insert the page to a CombinePDF object.
	#
	# We can either insert the PDFWriter as a new page:
	#   pdf = CombinePDF.new
	#   new_page = PDFWriter.new
	#   new_page.text_box "some text"
	#   pdf << new_page
	#   pdf.save "file_with_new_page.pdf"
	# Or we can insert the PDFWriter as an overlay (stamp / watermark) over existing pages:
	#   pdf = CombinePDF.new
	#   new_page = PDFWriter.new "some_file.pdf"
	#   new_page.text_box "some text"
	#   pdf.pages.each {|page| page << new_page }
	#   pdf.save "stamped_file.pdf"
	class PDFWriter < Hash

		def initialize(media_box = [0.0, 0.0, 612.0, 792.0])
			# indirect_reference_id, :indirect_generation_number
			self[:Type] = :Page
			self[:indirect_reference_id] = 0
			self[:Resources] = {}
			self[:Contents] = { is_reference_only: true , referenced_object: {indirect_reference_id: 0, raw_stream_content: ""} }
			self[:MediaBox] = media_box
		end
		# accessor (getter) for the :MediaBox element of the page
		def media_box
			self[:MediaBox]
		end
		# accessor (setter) for the :MediaBox element of the page
		# dimentions:: an Array consisting of four numbers (can be floats) setting the size of the media box.
		def media_box=(dimentions = [0.0, 0.0, 612.0, 792.0])
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
		# font_name:: a Symbol representing one of the 14 standard fonts. defaults to ":Helvetica" @see add_font
		# font_size:: a Fixnum for the font size, or :fit_text to fit the text in the box. defaults to ":fit_text"
		# text_color:: [R, G, B], an array with three floats, each in a value between 0 to 1 (gray will be "[0.5, 0.5, 0.5]").
		def text_box(text, properties = {})
			options = {
				text_alignment: :center,
				text_color: [0,0,0],
				text_stroke_color: nil,
				text_stroke_width: 0,
				font_name: :Helvetica,
				font_size: :fit_text,
				border_color: [0.5,0.5,0.5],
				border_width: 2,
				border_radius: 0,
				background_color: [0.7,0.7,0.7],
				opacity: 1,
				x: 0,
				y: 0,
				length: -1,
				height: -1,
			}
			options.update properties
			# reset the length and height to meaningful values, if negative
			options[:length] = media_box[2] - options[:x] if options[:length] < 0
			options[:height] = media_box[3] - options[:y] if options[:height] < 0
			# fit text in box, if requested
			if options[:font_size] == :fit_text
				options[:font_size] = self.fit_text text, options[:font_name], options[:length], options[:height]
			end


			# create box stream

			# reset x,y by text alignment - x,y are calculated from the buttom left
			# each unit (1) is 1/72 Inch
			x = options[:x]
			y = options[:y]
			# create text stream
			text_stream = ""
			text_stream << "BT\n" # the Begine Text marker			
			text_stream << PDFOperations._format_name_to_pdf(font options[:font_name]) # Set font name
			text_stream << " #{options[:font_size].to_f} Tf\n" # set font size and add font operator
			text_stream << "#{options[:text_color][0]} #{options[:text_color][0]} #{options[:text_color][0]} rg\n" # sets the color state
			text_stream << "#{x} #{y} Td\n" # set location for text object
			text_stream << PDFOperations._format_string_to_pdf(text) # insert the string in PDF format
			text_stream << " Tj\n ET\n" # the Text object operator and the End Text marker

			final_stream = ""
			# set graphic state for box
			final_stream << "q\nq\nq\n"
			box_graphic_state = graphic_state ca: options[:opacity], CA: options[:opacity], LW: options[:border_width], LC: 2, LJ:1,  LD: 0
			final_stream << "#{PDFOperations._object_to_pdf box_graphic_state} gs\n"
			final_stream << "DeviceRGB CS\nDeviceRGB cs\n"

			# set graphic state for text
			final_stream << "q\nq\nq\n"
			text_graphic_state = graphic_state({ca: options[:opacity], CA: options[:opacity], LW: options[:text_stroke_width], LC: 2, LJ: 1,  LD: 0})
			final_stream << "#{PDFOperations._object_to_pdf text_graphic_state} gs\n"
			final_stream << "DeviceRGB CS\nDeviceRGB cs\n"
			final_stream << "#{options[:text_color][0]} #{options[:text_color][1]} #{options[:text_color][2]} scn\n"
			if options[:text_stroke_width].to_i > 0 && options[:text_stroke_color]
				final_stream << "#{options[:text_stroke_color][0]} #{options[:text_stroke_color][1]} #{options[:text_stroke_color][2]} SCN\n"
				final_stream << "2 Tr\n"
			else
				final_stream << "0 Tr\n"
			end

			# clear graphic states
			final_stream << "Q\nQ\nQ\n"
			final_stream << "Q\nQ\nQ\n"

			contents << final_stream
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




# # text_box output example
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






