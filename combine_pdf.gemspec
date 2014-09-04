# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the CombinePDF library and the code
## is subject to the same license.
########################################################
Gem::Specification.new do |s|
	s.name = 'combine_pdf'
	s.version = '0.0.1'
	s.date = '2014-09-01'
	s.add_runtime_dependency 'ruby-rc4'
	s.summary = "Combine, stamp and watermark PDF files in pure Ruby."
	s.description = "A nifty gem, in pure Ruby, to parse PDF files and combine (merge) them with other PDF files, watermark them or stamp them (all using the PDF file format)."
	s.authors = ["Boaz Segev", "Masters of the open source community"]
	s.email = 'bsegev@gmail.com'
	s.files = Dir["{lib}/**/*.rb"] #["lib/combine_pdf.rb", "lib/combine_pdf/combine_pdf_pdf.rb", "lib/combine_pdf/combine_pdf_parser.rb" , "lib/combine_pdf/combine_pdf_decrypt.rb" , "lib/combine_pdf/combine_pdf_filter.rb" ]
	s.homepage = 'https://github.com/boazsegev/combine_pdf'
	s.license = 'GPLv3'
end
