# -*- encoding : utf-8 -*-





module CombinePDF
	module_function

	# Create an empty PDF object or create a PDF object from a file (parsing the file).
	# file_name:: is the name of a file to be parsed.
	def load(file_name = "")
		raise TypeError, "couldn't parse data, expecting type String" unless file_name.is_a?(String) || file_name.is_a?(Pathname)
		return PDF.new() if file_name == ''
		PDF.new( PDFParser.new(  IO.read(file_name, mode: 'rb').force_encoding(Encoding::ASCII_8BIT) ) )
	end
	def new(file_name = "")
		raise TypeError, "couldn't create PDF object, expecting type String" unless file_name.is_a?(String) || file_name.is_a?(Pathname)
		load(file_name) rescue parse(file_name)
	end

	# Create a PDF object from a raw PDF data (parsing the data).
	# data:: is a string that represents the content of a PDF file.
	def parse(data)
		raise TypeError, "couldn't parse and data, expecting type String" unless data.is_a? String
		PDF.new( PDFParser.new(data) )
	end
	# makes a PDFWriter object
	#
	# PDFWriter objects reresent an empty page and have the method "textbox"
	# that adds content to that page.
	#
	# PDFWriter objects are used internally for numbering pages (by creating a PDF page
	# with the page number and "stamping" it over the existing page).
	#
	# ::mediabox an Array representing the size of the PDF document. defaults to: [0.0, 0.0, 612.0, 792.0]
	#
	# if the page is PDFWriter object as a stamp, the final size will be that of the original page.
	def create_page(mediabox = [0, 0, 595.3, 841.9])
		PDFWriter.new mediabox
	end

	# makes a PDF object containing a table
	#
	# all the pages in this PDF object are PDFWriter objects and are
	# writable using the texbox function (should you wish to add a title, or more info)
	#
	# the main intended use of this method is to create indexes (a table of contents) for merged data.
	#
	# example:
	#   pdf = CombinePDF.create_table headers: ["header 1", "another header"], table_data: [ ["this is one row", "with two columns"] , ["this is another row", "also two columns", "the third will be ignored"] ]
	#   pdf.save "table_file.pdf"
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
	# max_rows:: the number of rows per page, INCLUDING the header row. deafults to 25.
	# page_size:: the size of the page in PDF points. defaults to [0, 0, 595.3, 841.9] (A4).
	def create_table(options = {})
		options[:max_rows] = options[:rows_per_page] if options[:rows_per_page]

		page_size = options[:page_size] || [0, 0, 595.3, 841.9]
		table = PDF.new()
		page = nil
		until options[:table_data].empty?
			page = create_page page_size
			page.write_table options
			table << page
		end
		table

		# defaults = {
		# 	headers: nil,
		# 	table_data: [[]],
		# 	font: nil,
		# 	header_font: nil,
		# 	max_font_size: 14,
		# 	column_widths: nil,
		# 	header_color: [0.8, 0.8, 0.8],
		# 	main_color: nil,
		# 	alternate_color: [0.95, 0.95, 0.95],
		# 	font_color: [0,0,0],
		# 	border_color: [0,0,0],
		# 	border_width: 1,
		# 	header_align: :center,
		# 	row_align: nil,
		# 	direction: :ltr,
		# 	rows_per_page: 25,
		# 	page_size: [0, 0, 595.3, 841.9] #A4
		# }
		# options = defaults.merge options
		# options[:header_font] = options[:font] unless options[:header_font]
		# options[:row_align] ||= ( (options[:direction] == :rtl) ? :right : :left )
		# # assert table_data is an array of arrays
		# return false unless (options[:table_data].select {|r| !r.is_a?(Array) }).empty?
		# # compute sizes
		# page_size = options[:page_size]
		# top = page_size[3] * 0.9
		# height = page_size[3] * 0.8 / options[:rows_per_page]
		# from_side = page_size[2] * 0.1
		# width = page_size[2] * 0.8
		# columns = options[:table_data][0].length
		# column_widths = []
		# columns.times {|i| column_widths << (width/columns) }
		# if options[:column_widths]
		# 	scale = 0
		# 	options[:column_widths].each {|w| scale += w}
		# 	column_widths = []
		# 	options[:column_widths].each { |w|  column_widths << (width*w/scale) }
		# end
		# column_widths = column_widths.reverse if options[:direction] == :rtl
		# # set pdf object and start writing the data
		# table = PDF.new()
		# page = nil
		# rows_per_page = options[:rows_per_page]
		# row_number = rows_per_page + 1

		# options[:table_data].each do |row_data|
		# 	if row_number > rows_per_page
		# 		page = create_page page_size
		# 		table << page
		# 		row_number = 1
		# 		# add headers
		# 		if options[:headers]
		# 			x = from_side
		# 			headers = options[:headers]
		# 			headers = headers.reverse if options[:direction] == :rtl
		# 			column_widths.each_index do |i|
		# 				text = headers[i].to_s
		# 				page.textbox text, {x: x, y: (top - (height*row_number)), width: column_widths[i], height: height, box_color: options[:header_color], text_align: options[:header_align] }.merge(options).merge({font: options[:header_font]})
		# 				x += column_widths[i]
		# 			end
		# 			row_number += 1
		# 		end
		# 	end
		# 	x = from_side
		# 	row_data = row_data.reverse if options[:direction] == :rtl
		# 	column_widths.each_index do |i|
		# 		text = row_data[i].to_s
		# 		box_color = options[:main_color]
		# 		box_color = options[:alternate_color] if options[:alternate_color] && row_number.odd?
		# 		page.textbox text, {x: x, y: (top - (height*row_number)), width: column_widths[i], height: height, box_color: box_color, text_align: options[:row_align]}.merge(options)
		# 		x += column_widths[i]
		# 	end			
		# 	row_number += 1
		# end
		# table
	end
	def new_table(options = {})
		create_table options
	end

	# calculate a CTM value for a specific transformation.
	#
	# this could be used to apply transformation in #textbox and to convert visual
	# rotation values into actual rotation transformation.
	#
	# this method accepts a Hash containing any of the following parameters:
	#
	# deg:: the clockwise rotation to be applied, in degrees
	# tx:: the x translation to be applied.
	# ty:: the y translation to be applied.
	# sx:: the x scaling to be applied.
	# sy:: the y scaling to be applied.
	#
	# * scaling will be applied after the transformation is applied.
	#
	def calc_ctm parameters
		p = {deg: 0, tx: 0, ty: 0, sx: 1, sy: 1}.merge parameters
		r = p[:deg] * Math::PI / 180
		s = Math.sin(r)
		c = Math.cos(r)
		# start with tranlation matrix
		m = Matrix[ [1,0,0], [0,1,0], [ p[:tx], p[:ty], 1] ]
		# then rotate
		m = m * Matrix[ [c, s, 0], [-s, c, 0], [0, 0, 1]] if parameters[:deg]
		# then scale
		m = m * Matrix[ [p[:sx], 0, 0], [0, p[:sy], 0], [0,0,1] ] if parameters[:sx] || parameters[:sy]
		# flaten array and round to 6 digits
		m.to_a.flatten.values_at(0,1,3,4,6,7).map! {|f| f.round 6}
	end

	# adds a correctly formatted font object to the font library.
	#
	# registered fonts will remain in the library and will only be embeded in
	# PDF objects when they are used by PDFWriter objects (for example, for numbering pages).
	#
	# this function enables plug-ins to expend the font functionality of CombinePDF.
	#
	# font_name:: a Symbol with the name of the font. if the fonts exists in the library, it will be overwritten!
	# font_metrics:: a Hash of font metrics, of the format char => {wx: char_width, boundingbox: [left_x, buttom_y, right_x, top_y]} where char == character itself (i.e. " " for space). The Hash should contain a special value :missing for the metrics of missing characters. an optional :wy might be supported in the future, for up to down fonts.
	# font_pdf_object:: a Hash in the internal format recognized by CombinePDF, that represents the font object.
	# font_cmap:: a CMap dictionary Hash) which maps unicode characters to the hex CID for the font (i.e. {"a" => "61", "z" => "7a" }).
	def register_font(font_name, font_metrics, font_pdf_object, font_cmap = nil)
		Fonts.register_font font_name, font_metrics, font_pdf_object, font_cmap
	end

	# adds an existing font (from any PDF Object) to the font library.
	#
	# returns the font on success or false on failure.
	#
	# example:
	#   fonts = CombinePDF.new("japanese_fonts.pdf").fonts(true)
	#   CombinePDF.register_font_from_pdf_object :david, fonts[0]
	#
	# VERY LIMITTED SUPPORT:
	# - at the moment it only imports Type0 fonts.
	# - also, to extract the Hash of the actual font object you were looking for, is not a trivial matter. I do it on the console.
	# font_name:: a Symbol with the name of the font registry. if the fonts exists in the library, it will be overwritten! 
	# font_object:: a Hash in the internal format recognized by CombinePDF, that represents the font object.
	def register_existing_font font_name, font_object
		Fonts.register_font_from_pdf_object font_name, font_object
	end
	def register_font_from_pdf_object font_name, font_object
		register_existing_font font_name, font_object
	end
end
