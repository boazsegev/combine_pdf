# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################




module CombinePDF

	# This module injects page editing methods into existing page objects and the PDFWriter objects.
	module Page_Methods
		include Renderer

		# holds the string that starts a PDF graphic state container - used for wrapping malformed PDF content streams.
		CONTENT_CONTAINER_START = 'q'
		# holds the string that ends a PDF graphic state container - used for wrapping malformed PDF content streams.
		CONTENT_CONTAINER_MIDDLE = "Q\nq"
		# holds the string that ends a PDF graphic state container - used for wrapping malformed PDF content streams.
		CONTENT_CONTAINER_END = 'Q'

		# accessor (getter) for the secure_injection setting
		def secure_injection
			warn "**Deprecation Warning**: the `Page_Methods#secure_injection`, `Page_Methods#make_unsecure` and `Page_Methods#make_secure` methods are deprecated. Use `Page_Methods#copy(true)` for safeguarding against font/resource conflicts when 'stamping' one PDF page over another."
			@secure_injection
		end
		# accessor (setter) for the secure_injection setting
		def secure_injection= safe
			warn "**Deprecation Warning**: the `Page_Methods#secure_injection`, `Page_Methods#make_unsecure` and `Page_Methods#make_secure` methods are deprecated. Use `Page_Methods#copy(true)` for safeguarding against font/resource conflicts when 'stamping' one PDF page over another."
			@secure_injection = safe
		end
		# sets secure_injection to `true` and returns self, allowing for chaining methods
		def make_secure
			warn "**Deprecation Warning**: the `Page_Methods#secure_injection`, `Page_Methods#make_unsecure` and `Page_Methods#make_secure` methods are deprecated. Use `Page_Methods#copy(true)` for safeguarding against font/resource conflicts when 'stamping' one PDF page over another."
			@secure_injection = true
			self
		end
		# sets secure_injection to `false` and returns self, allowing for chaining methods
		def make_unsecure
			warn "**Deprecation Warning**: the `Page_Methods#secure_injection`, `Page_Methods#make_unsecure` and `Page_Methods#make_secure` methods are deprecated. Use `Page_Methods#copy(true)` for safeguarding against font/resource conflicts when 'stamping' one PDF page over another."
			@secure_injection = false
			self
		end

		# the injection method
		def << obj
			inject_page obj, true
		end
		def >> obj
			inject_page obj, false
		end
		def inject_page obj, top = true
			
			raise TypeError, "couldn't inject data, expecting a PDF page (Hash type)" unless obj.is_a?(Page_Methods)

			obj = obj.copy( should_secure?(obj) ) #obj.copy(secure_injection)

			# following the reference chain and assigning a pointer to the correct Resouces object.
			# (assignments of Strings, Arrays and Hashes are pointers in Ruby, unless the .dup method is called)

			# injecting each of the values in the injected Page
			res = resources
			obj.resources.each do |key, new_val|
				unless PDF::PRIVATE_HASH_KEYS.include? key # keep CombinePDF structual data intact.
					if res[key].nil?
						res[key] = new_val
					elsif res[key].is_a?(Hash) && new_val.is_a?(Hash)
						new_val.update resources[key] # make sure the old values are respected
						res[key].update new_val # transfer old and new values to the injected page
					end #Do nothing if array - ot is the PROC array, which is an issue
				end
			end
			resources[:ProcSet] = [:PDF, :Text, :ImageB, :ImageC, :ImageI] # this was recommended by the ISO. 32000-1:2008

			if top # if this is a stamp (overlay)
				insert_content CONTENT_CONTAINER_START, 0
				insert_content CONTENT_CONTAINER_MIDDLE
				self[:Contents].concat obj[:Contents]
				insert_content CONTENT_CONTAINER_END
			else #if this was a watermark (underlay? would be lost if the page was scanned, as white might not be transparent)
				insert_content CONTENT_CONTAINER_MIDDLE, 0
				insert_content CONTENT_CONTAINER_START, 0
				self[:Contents].insert 1, *obj[:Contents]
				insert_content CONTENT_CONTAINER_END
			end
			init_contents

			self
		end

		# accessor (setter) for the :MediaBox element of the page
		# dimensions:: an Array consisting of four numbers (can be floats) setting the size of the media box.
		def mediabox=(dimensions = [0.0, 0.0, 612.0, 792.0])
			self[:MediaBox] = dimensions
		end

		# accessor (getter) for the :MediaBox element of the page
		def mediabox
			actual_object self[:MediaBox]
		end

		# accessor (setter) for the :CropBox element of the page
		# dimensions:: an Array consisting of four numbers (can be floats) setting the size of the media box.
		def cropbox=(dimensions = [0.0, 0.0, 612.0, 792.0])
			self[:CropBox] = dimensions
		end

		# accessor (getter) for the :CropBox element of the page
		def cropbox
			actual_object self[:CropBox]
		end

		# get page size
		def page_size
			cropbox || mediabox			
		end

		# accessor (getter) for the :Resources element of the page
		def resources
			self[:Resources] ||= {}
			self[:Resources][:referenced_object] || self[:Resources]
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
		# text_padding:: a Float between 0 and 1, setting the padding for the text. defaults to 0.05 (5%).
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
				text_padding: 0.1,
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
				opacity: 1,
				ctm: nil # ~= [1,0,0,1,0,0]
			}
			options.update properties
			# reset the length and height to meaningful values, if negative
			options[:width] = mediabox[2] - options[:x] + options[:width] if options[:width] <= 0
			options[:height] = mediabox[3] - options[:y] + options[:height] if options[:height] <= 0

			# reset the padding value
			options[:text_padding] = 0 if options[:text_padding].to_f >= 1

			# create box stream
			box_stream = ""
			# set graphic state for box
			if options[:box_color] || (options[:border_width].to_i > 0 && options[:border_color])
				# compute x and y position for text
				x = options[:x]
				y = options[:y]

				# set graphic state for the box
				box_stream << "q\n"
				box_stream << "#{options[:ctm].join ' '} cm\n" if options[:ctm]
				box_graphic_state = { ca: options[:opacity], CA: options[:opacity], LW: options[:border_width], LC: 0, LJ: 0,  LD: 0}
				if options[:box_radius] != 0 # if the text box has rounded corners
					box_graphic_state[:LC], box_graphic_state[:LJ] =  2, 1
				end
				box_graphic_state = graphic_state box_graphic_state # adds the graphic state to Resources and gets the reference
				box_stream << "#{object_to_pdf box_graphic_state} gs\n"

				# the following line was removed for Acrobat Reader compatability
				# box_stream << "DeviceRGB CS\nDeviceRGB cs\n"

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
				box_stream << "Q\n"
			end
			contents << box_stream

			# reset x,y by text alignment - x,y are calculated from the buttom left
			# each unit (1) is 1/72 Inch
			# create text stream
			text_stream = ""
			if !text.to_s.empty? && options[:font_size] != 0 && (options[:font_color] || options[:stroke_color])
				# compute x and y position for text
				x = options[:x] + (options[:width]*options[:text_padding])
				y = options[:y] + (options[:height]*options[:text_padding])

				# set the fonts (fonts array, with :Helvetica as fallback).
				fonts = [*options[:font], :Helvetica]
				# fit text in box, if requested
				font_size = options[:font_size]
				if options[:font_size] == :fit_text
					font_size = self.fit_text text, fonts, (options[:width]*(1-options[:text_padding])), (options[:height]*(1-options[:text_padding]))
					font_size = options[:max_font_size] if options[:max_font_size] && font_size > options[:max_font_size]
				end

				text_size = dimensions_of text, fonts, font_size

				if options[:text_align] == :center
					x = ( ( options[:width]*(1-(2*options[:text_padding])) ) - text_size[0] )/2 + x
				elsif options[:text_align] == :right
					x = ( ( options[:width]*(1-(1.5*options[:text_padding])) ) - text_size[0] ) + x
				end
				if options[:text_valign] == :center
					y = ( ( options[:height]*(1-(2*options[:text_padding])) ) - text_size[1] )/2 + y
				elsif options[:text_valign] == :top
					y = ( options[:height]*(1-(1.5*options[:text_padding])) ) - text_size[1] + y
				end

				# set graphic state for text
				text_stream << "q\n"
				text_stream << "#{options[:ctm].join ' '} cm\n" if options[:ctm]
				text_graphic_state = graphic_state({ca: options[:opacity], CA: options[:opacity], LW: options[:stroke_width].to_f, LC: 2, LJ: 1,  LD: 0 })
				text_stream << "#{object_to_pdf text_graphic_state} gs\n"

				# the following line was removed for Acrobat Reader compatability
				# text_stream << "DeviceRGB CS\nDeviceRGB cs\n"

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
				encode_text(text, fonts).each do |encoded|
					text_stream << "BT\n" # the Begine Text marker			
					text_stream << format_name_to_pdf(set_font encoded[0]) # Set font name
					text_stream << " #{font_size.round 3} Tf\n" # set font size and add font operator
					text_stream << "#{x.round 4} #{y.round 4} Td\n" # set location for text object
					text_stream << (  encoded[1] ) # insert the encoded string to the stream
					text_stream << " Tj\n" # the Text object operator and the End Text marker
					text_stream << "ET\n" # the Text object operator and the End Text marker
					x += encoded[2]/1000*font_size #update text starting point
					y -= encoded[3]/1000*font_size #update text starting point
				end
				# exit graphic state for text
				text_stream << "Q\n"
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


		# This method moves the Page[:Rotate] property into the page's data stream, so that
		# "what you see is what you get".
		#
		# This is usful in cases where there might be less control over the source PDF files,
		# and the user assums that the PDF page's data is the same as the PDF's pages
		# on screen display (Rotate rotates a page but leaves the data in the original orientation).
		#
		# The method returns the page object, thus allowing method chaining (i.e. `page[:Rotate] = 90; page.textbox('hello!').fix_rotation.textbox('hello!')`)
		def fix_rotation
			return self if self[:Rotate].to_f == 0.0 || mediabox.nil?
			# calculate the rotation
			r = self[:Rotate].to_f * Math::PI / 180
			s = Math.sin(r).round 6
			c = Math.cos(r).round 6
			ctm = [c, s, -s, c]
			# calculate the translation (move the origin of x,y to the new origin).
			x = mediabox[2] - mediabox[0]
			y = mediabox[3] - mediabox[1]
			ctm.push( ( (x*c).abs - x*c + (y*s).abs + y*s )/2 , ( (x*s).abs - x*s + (y*c).abs - y*c )/2 )

			# insert the rotation stream into the current content stream
			insert_content "q\n#{ctm.join ' '} cm\n", 0
			# close the rotation stream
			insert_content CONTENT_CONTAINER_END
			# reset the mediabox and cropbox values - THIS IS ONLY FOR ORIENTATION CHANGE...
			if ((self[:Rotate].to_f / 90)%2) != 0
				self[:MediaBox] = self[:MediaBox].values_at(1,0,3,2)
				self[:CropBox] = self[:CropBox].values_at(1,0,3,2) if self[:CropBox]
			end
			# reset the Rotate property
			self.delete :Rotate
			# disconnect the content stream, so that future inserts aren't rotated
			@contents = false #init_contents

			# always return self, for chaining.
			self
		end

		# resizes the page relative to it's current viewport (either the cropbox or the mediabox), setting the new viewport to the requested size.
		#
		# accepts:
		# new_size:: an Array with four elements: [X0, Y0, X_max, Y_max]. For example, A4: `[0, 0, 595, 842]`. It is important that the first two numbers are 0 unless a special effect is attempted. If the first two numbers change, the final result might not be the size requested, but the nearest possible transformation (calling the method again will allow a better resizing).
		# conserve_aspect_ratio:: whether to keep the current content in the same aspect ratio or to allow streaching. Defaults to true - so that although the content is resized, it might not fill the new size completely.
		def resize new_size = nil, conserve_aspect_ratio = true
			return page_size unless new_size
			c_mediabox = mediabox
			c_cropbox = cropbox
			c_size = c_cropbox || c_mediabox
			x_ratio = 1.0 * (new_size[2]-new_size[0]) / (c_size[2])#-c_size[0])
			y_ratio = 1.0 * (new_size[3]-new_size[1]) / (c_size[3])#-c_size[1])
			x_move = new_size[0] - c_size[0]
			y_move = new_size[1] - c_size[1]
			puts "ctm will be: #{x_ratio.round(4).to_s} 0 0 #{y_ratio.round(4).to_s} #{x_move} #{y_move}"
			self[:MediaBox] = [(c_mediabox[0] + x_move), (c_mediabox[1] + y_move), ((c_mediabox[2] * x_ratio) + x_move ), ((c_mediabox[3] * y_ratio) + y_move)]
			self[:CropBox] = [(c_cropbox[0] + x_move), (c_cropbox[1] + y_move), ((c_cropbox[2] * x_ratio) + x_move), ((c_cropbox[3] * y_ratio) + y_move)] if c_cropbox
			x_ratio = y_ratio = [x_ratio, y_ratio].min if conserve_aspect_ratio
			# insert the rotation stream into the current content stream
			# insert_content "q\n#{x_ratio.round(4).to_s} 0 0 #{y_ratio.round(4).to_s} 0 0 cm\n1 0 0 1 #{x_move} #{y_move} cm\n", 0
			insert_content "q\n#{x_ratio.round(4).to_s} 0 0 #{y_ratio.round(4).to_s} #{x_move} #{y_move} cm\n", 0
			# close the rotation stream
			insert_content CONTENT_CONTAINER_END
			# disconnect the content stream, so that future inserts aren't rotated
			@contents = false #init_contents

			# always return self, for chaining.
			self
		end

		# rotate the page 90 degrees counter clockwise
		def rotate_left
			self[:Rotate] = self[:Rotate].to_f + 90
			fix_rotation
		end
		# rotate the page 90 degrees clockwise
		def rotate_right
			self[:Rotate] = self[:Rotate].to_f - 90
			fix_rotation
		end
		# rotate the page by 180 degrees
		def rotate_180
			self[:Rotate] = self[:Rotate].to_f +180
			fix_rotation
		end
		# get or set (by clockwise rotation) the page's orientation
		#
		# accepts one optional parameter:
		# force:: to get the orientation, pass nil. to set the orientatiom, set fource to either :portrait or :landscape. defaults to nil (get orientation).
		# clockwise:: sets the rotation directions. defaults to true (clockwise rotation).
		#
		# returns the current orientation (:portrait or :landscape) if used to get the orientation.
		# otherwise, if used to set the orientation, returns the page object to allow method chaining.
		#
		# * Notice: a square page always returns the :portrait value and is ignored when trying to set the orientation.
		def orientation force = nil, clockwise = true
			a = page_size
			unless force
				return (a[2] - a[0] > a[3] - a[1]) ? :landscape : :portrait
			end
			unless orientation == force || (a[2] - a[0] == a[3] - a[1])
				self[:Rotate] = 0;
				clockwise ? rotate_right : rotate_left
			end
			self
		end


		# Writes a table to the current page, removing(!) the written rows from the table_data Array.
		#
		# since the table_data Array is updated, it is possible to call this method a few times,
		# each time creating or moving to the next page, until table_data.empty? returns true.
		#
		# accepts a Hash with any of the following keys as well as any of the PDFWriter#textbox options:
		# headers:: an Array of strings with the headers (will be repeated every page).
		# table_data:: as Array of Arrays, each containing a string for each column. the first row sets the number of columns. extra columns will be ignored.
		# font:: a registered or standard font name (see PDFWriter). defaults to nil (:Helvetica).
		# header_font:: a registered or standard font name for the headers (see PDFWriter). defaults to nil (the font for all the table rows).
		# max_font_size:: the maximum font size. if the string doesn't fit, it will be resized. defaults to 14.
		# column_widths:: an array of relative column widths ([1,2] will display only the first two columns, the second twice as big as the first). defaults to nil (even widths).
		# header_color:: the header color. defaults to [0.8, 0.8, 0.8] (light gray).
		# main_color:: main row color. defaults to nil (transparent / white).
		# alternate_color:: alternate row color. defaults to [0.95, 0.95, 0.95] (very light gray).
		# font_color:: font color. defaults to [0,0,0] (black).
		# border_color:: border color. defaults to [0,0,0] (black).
		# border_width:: border width in PDF units. defaults to 1.
		# header_align:: the header text alignment within each column (:right, :left, :center). defaults to :center.
		# row_align:: the row text alignment within each column. defaults to :left (:right for RTL table).
		# direction:: the table's writing direction (:ltr or :rtl). this reffers to the direction of the columns and doesn't effect text (rtl text is automatically recognized). defaults to :ltr.
		# max_rows:: the maximum number of rows to actually draw, INCLUDING the header row. deafults to 25.
		# xy:: an Array specifying the top-left corner of the table. defaulte to [page_width*0.1, page_height*0.9].
		# size:: an Array specifying the height and the width of the table.  defaulte to [page_width*0.8, page_height*0.8].
		def write_table(options = {})
			defaults = {
				headers: nil,
				table_data: [[]],
				font: nil,
				header_font: nil,
				max_font_size: 14,
				column_widths: nil,
				header_color: [0.8, 0.8, 0.8],
				main_color: nil,
				alternate_color: [0.95, 0.95, 0.95],
				font_color: [0,0,0],
				border_color: [0,0,0],
				border_width: 1,
				header_align: :center,
				row_align: nil,
				direction: :ltr,
				max_rows: 25,
				xy: nil,
				size: nil
			}
			options = defaults.merge options
			raise "method call error! not enough rows allowed to create table" if (options[:max_rows].to_i < 1 && options[:headers]) || (options[:max_rows].to_i <= 0)
			options[:header_font] ||= options[:font]
			options[:row_align] ||= ( (options[:direction] == :rtl) ? :right : :left )
			options[:xy] ||= [( (page_size[2]-page_size[0])*0.1 ), ( (page_size[3]-page_size[1])*0.9 )]
			options[:size] ||= [( (page_size[2]-page_size[0])*0.8 ), ( (page_size[3]-page_size[1])*0.8 )]
			# assert table_data is an array of arrays
			return false unless (options[:table_data].select {|r| !r.is_a?(Array) }).empty?
			# compute sizes
			top = options[:xy][1]
			height = options[:size][1] / options[:max_rows]
			from_side = options[:xy][0]
			width = options[:size][0]
			columns = options[:table_data][0].length
			column_widths = []
			columns.times {|i| column_widths << (width/columns) }
			if options[:column_widths]
				scale = 0
				options[:column_widths].each {|w| scale += w}
				column_widths = []
				options[:column_widths].each { |w|  column_widths << (width*w/scale) }
			end
			column_widths = column_widths.reverse if options[:direction] == :rtl
			# set count and start writing the data
			row_number = 1

			until (options[:table_data].empty? ||  row_number > options[:max_rows])
				# add headers
				if options[:headers] && row_number == 1
					x = from_side
					headers = options[:headers]
					headers = headers.reverse if options[:direction] == :rtl
					column_widths.each_index do |i|
						text = headers[i].to_s
						textbox text, {x: x, y: (top - (height*row_number)), width: column_widths[i], height: height, box_color: options[:header_color], text_align: options[:header_align] }.merge(options).merge({font: options[:header_font]})
						x += column_widths[i]
					end
					row_number += 1
				end
				x = from_side
				row_data = options[:table_data].shift
				row_data = row_data.reverse if options[:direction] == :rtl
				column_widths.each_index do |i|
					text = row_data[i].to_s
					box_color = (options[:alternate_color] && ( (row_number.odd? && options[:headers]) || row_number.even? ) ) ? options[:alternate_color] : options[:main_color]
					textbox text, {x: x, y: (top - (height*row_number)), width: column_widths[i], height: height, box_color: box_color, text_align: options[:row_align]}.merge(options)
					x += column_widths[i]
				end			
				row_number += 1
			end
			self
		end

		# creates a copy of the page. if the :secure flag is set to true, the resource indentifiers (fonts etc') will be renamed in order to secure their uniqueness.
		def copy(secure = false)
		# since only the Content streams are modified (Resource hashes are created anew),
		# it should be safe (and a lot faster) to create a deep copy only for the content hashes and streams.
			delete :Parent
			prep_content_array
			page_copy = self.clone
			page_copy[:Contents] = page_copy[:Contents].map do |obj|
				obj = obj.dup
				obj[:referenced_object] = obj[:referenced_object].dup if obj[:referenced_object]
				obj[:referenced_object][:raw_stream_content] = obj[:referenced_object][:raw_stream_content].dup if obj[:referenced_object] && obj[:referenced_object][:raw_stream_content]
				obj
			end
			if page_copy[:Resources]
				page_res = page_copy[:Resources] = page_copy[:Resources].dup
				page_res = page_copy[:Resources][:referenced_object] = page_copy[:Resources][:referenced_object].dup if page_copy[:Resources][:referenced_object]
				page_res.each do |k, v|
					v = page_res[k] = v.dup if v.is_a?(Array) || v.is_a?(Hash)
					v = v[:referenced_object] = v[:referenced_object].dup if v.is_a?(Hash) && v[:referenced_object]
					v = v[:referenced_object] = v[:referenced_object].dup if v.is_a?(Hash) && v[:referenced_object]
				end
			end
			return page_copy.instance_exec(secure || @secure_injection) { |s| secure_for_copy if s ; init_contents; self }
		end

		###################################
		# protected methods

		protected

		# accessor (getter) for the stream in the :Contents element of the page
		# after getting the string object, you can operate on it but not replace it (use << or other String methods).
		def contents
			@contents ||= init_contents
		end
		#initializes the content stream in case it was not initialized before
		def init_contents
			self[:Contents] = self[:Contents][:referenced_object][:indirect_without_dictionary] if self[:Contents][:referenced_object] && self[:Contents][:referenced_object][:indirect_without_dictionary]
			self[:Contents].delete({ is_reference_only: true , referenced_object: {indirect_reference_id: 0, raw_stream_content: ''} })
			# wrap content streams
			insert_content 'q', 0
			insert_content 'Q'

			# Prep content
			@contents = ''
			insert_content @contents
			@contents
		end

		# adds a string or an object to the content stream, at the location indicated
		#
		# accepts:
		# object:: can be a string or a hash object
		# location:: can be any numeral related to the possition in the :Contents array. defaults to -1 == insert at the end.
		def insert_content object, location = -1
			object = { is_reference_only: true , referenced_object: {indirect_reference_id: 0, raw_stream_content: object} } if object.is_a?(String)
			raise TypeError, "expected a String or Hash object." unless object.is_a?(Hash)
			prep_content_array
			self[:Contents].insert location, object
			self[:Contents].flatten!
			self
		end

		def prep_content_array
			return self if self[:Contents].is_a?(Array)
			self[:Contents] = self[:Contents][:referenced_object] if self[:Contents].is_a?(Hash) && self[:Contents][:referenced_object] && self[:Contents][:referenced_object].is_a?(Array)
			self[:Contents] = [ self[:Contents] ].compact
			self
		end

		#returns the basic font name used internally
		def base_font_name
			@base_font_name ||= "Writer" + SecureRandom.hex(7) + "PDF"
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
			name = (base_font_name + (resources[:Font].length + 1).to_s).to_sym
			# get font object
			font_object = Fonts.get_font(font)
			# return false if the font wan't found in the library.
			return false unless font_object
			# add object to reasource
			resources[:Font][name] = font_object
			#return name
			name
		end
		# register or get a registered graphic state dictionary.
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
			name = (SecureRandom.hex(9)).to_sym
			# add object to reasource
			resources[:ExtGState][name] = graphic_state_dictionary
			#return name
			name
		end

		# encodes the text in an array of [:font_name, <PDFHexString>] for use in textbox
		def encode_text text, fonts
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
			rtl_replaces = { '(' => ')', ')' => '(',
							'[' => ']', ']'=>'[',
							'{' => '}', '}'=>'{',
							'<' => '>', '>'=>'<',
							}
			return text unless text =~ /[#{rtl_characters}]/

			out = []
			scanner = StringScanner.new text
			until scanner.eos? do
				if scanner.scan /[#{rtl_characters} ]/
					out.unshift scanner.matched
				elsif scanner.scan /[^#{rtl_characters}]+/
					if out.empty? && scanner.matched.match(/[\s]$/) && !scanner.eos?
						white_space_to_move = scanner.matched.match(/[\s]+$/).to_s
						out.unshift scanner.matched[0..-1-white_space_to_move.length]
						out.unshift white_space_to_move
					elsif scanner.matched.match /^[\(\)\[\]\{\}\<\>]$/
						out.unshift rtl_replaces[scanner.matched]
					else
						out.unshift scanner.matched
					end
				end
			end
			out.join.strip
		end


		# copy_and_secure_for_injection(page)
		# - page is a page in the pages array, i.e.
		#   pdf.pages[0]
		# takes a page object and:
		#
		# makes a deep copy of the page (Ruby defaults to pointers, so this will copy the memory).
		#
		# then it will rewrite the content stream with renamed resources, so as to avoid name conflicts.
		def secure_for_copy
			# initiate dictionary from old names to new names
			names_dictionary = {}

			# travel every dictionary to pick up names (keys), change them and add them to the dictionary
			res = self.resources
			res.each do |k,v|
				if v.is_a?(Hash)
					# if k == :XObject
					# 	self[:Resources][k] = v.dup
					# 	next
					# end
					new_dictionary = {}
					new_name = "Combine" + SecureRandom.hex(7) + "PDF"
					i = 1
					v.each do |old_key, value|
						new_key = (new_name + i.to_s).to_sym
						names_dictionary[old_key] = new_key
						new_dictionary[new_key] = value
						i += 1
					end
					res[k] = new_dictionary
				end
			end

			# now that we have replaced the names in the resources dictionaries,
			# it is time to replace the names inside the stream
			# we will need to make sure we have access to the stream injected
			# we will user PDFFilter.inflate_object
			self[:Contents].each do |c|
				stream = actual_object(c)
				PDFFilter.inflate_object stream
				names_dictionary.each do |old_key, new_key|
					stream[:raw_stream_content].gsub! object_to_pdf(old_key), object_to_pdf(new_key)  ##### PRAY(!) that the parsed datawill be correctly reproduced! 
				end
				# # # the following code isn't needed now that we wrap both the existing and incoming content streams.
				# # patch back to PDF defaults, for OCRed PDF files.
				# stream[:raw_stream_content] = "q\n0 0 0 rg\n0 0 0 RG\n0 Tr\n1 0 0 1 0 0 cm\n%s\nQ\n" % stream[:raw_stream_content]
			end
			self
		end

		# @return [true, false] returns true if there are two different resources sharing the same named reference.
		def should_secure?(page)
			# travel every dictionary to pick up names (keys), change them and add them to the dictionary
			res = self.resources
			foreign_res = page.resources
			res.each {|k,v| v.keys.each {|name| return true if foreign_res[k] && foreign_res[k][name] && foreign_res[k][name] != v[name]} if v.is_a?(Hash) }
			false
		end

	end
	
end





