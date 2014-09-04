# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################



module CombinePDF

	#@private
	#:nodoc: all
	class PDFWriter

		def initialize(media_box = [0.0, 0.0, 612.0, 792.0])
			@content_stream = {}
			@media_box = media_box
		end

		########################################################
		## textbox
		## - font_name: :font_name
		## The PostScript names of 14 Type 1 fonts, known as the standard 14 fonts, are as follows:
		## Times-Roman, Helvetica, Courier, Symbol, Times-Bold, Helvetica-Bold, Courier-Bold, ZapfDingbats, Times-Italic, Helvetica- Oblique, Courier-Oblique, Times-BoldItalic, Helvetica-BoldOblique, Courier-BoldOblique
		## - text_color: [R, G, B]
		## an array with three floats, each in a value between 0 to 1.
		## First value is Red, second Green and last is Blue (RGB color system)
		def add_text_box(text, args = {})
			options = {
				text_alignment: :center,
				text_color: [1,1,1],
				# text_stroke: nil,
				font_name: :Helvetica,
				font_type: :Type1,
				font_object: nil,
				font_size: 12,
				border_color: nil,
				border_width: nil,
				border_radius: nil,
				background_color: nil,
				opacity: 1,
				x: 0,
				y: 0,
				length: -1,
				height: -1,
			}
			# create font object
			font_object = { Type: :Font, Subtype: options[:font_type], BaseFont: options[:font_name]}
			if options[:font_object].is_a?(Hash) && options[:font_object][:indirect_reference_id] && options[:font_object][:indirect_generation_number] && (options[:font_object][:is_reference_only] != true)
				font_object = {is_reference_only: true, referenced_object: font_object}
			end

			# create resources object
			font_name = ("MyFont" + rand(99) ).to_sym
			resources_object = {Resources: {Font: { font_name => font_object }     }    }
			# create box stream

			# reset x,y by text alignment - x,y are calculated from the buttom left
			# each unit (1) is 1/72 Inch
			x = options[:x]
			y = options[:y]
			# create text stream
			text_stream = ""
			text_stream << "BT\n" # the Begine Text marker			
			text_stream << PDFOperations._format_name_to_pdf(font_name) # Set font name
			text_stream << " #{options[:font_size].to_f} Tf\n" # set font size and add font operator
			text_stream << "#{options[:text_color][0]} #{options[:text_color][0]} #{options[:text_color][0]} rg\n" # sets the color state
			text_stream << " #{options[:opacity].to_f} ca\n" # set opacity (alpha) for graphic state.
			text_stream << "#{x} #{y} Td\n" # set location for text object
			text_stream << PDFOperations._format_string_to_pdf(text) # insert the string in PDF format
			text_stream << " Tj\n ET\n" # the Text object operator and the End Text marker
		end

		########################################################
		## add_content_to_pages(pages = [], location = :above)
		## pages - a page hash or an array of pages
		## location - :above to place content over existing content or :below to place content under existing content
		def add_content_to_pages(pages = [], location = :above)
			if pages.is_a?(Array)
				pages.each {|p| add_content_to_pages p, location}
			elsif pages.is_a?(Hash)
				#####
				##add content stream to page
			end
		end
		########################################################
		## make_into_page()
		## takes no arguments and returns the contents stream within a page (to be added as an indipendent page to the PDF object)
		def make_into_page
			{Type: :Page, }
		end

		########################################################
		## to_pdf()
		## prints out the content stream as raw PDF
		## file_name - the name of the file to which to save the data (will be overwritten).
		## if file_name is given, save to file.
		def to_pdf( file_name = nil)
			pdf = PDF.new
			pdf << make_into_page
			if file_name
				pdf.save file_name
			else
				pdf.to_pdf
			end
		end

	end
	
end



