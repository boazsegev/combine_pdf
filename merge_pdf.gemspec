# -*- encoding : utf-8 -*-
########################################################
## Thoughts from reading the ISO 32000-1:2008
## this file is part of the MergePDF library and the code
## is subject to the same license.
########################################################
Gem::Specification.new do |s|
	s.name = 'merge_pdf'
	s.version = '0.0.1'
	s.date = '2014-09-01'
	s.summary = "Merge, stamp and watermark PDF files in pure Ruby."
	s.description = "A nifty gem, in pure Ruby, to parse PDF files and merge them with other PDF files, watermark them or stamp them (all using the PDF file format)."
	s.authors = ["Boaz Segev", "Masters of the open source community"]
	s.email = 'bsegev@gmail.com'
	s.files = ["lib/merge_pdf.rb", "lib/merge_pdf/merge_pdf_pdf.rb", "lib/merge_pdf/merge_pdf_parser.rb" , "lib/merge_pdf/merge_pdf_decrypt.rb" , "lib/merge_pdf/merge_pdf_filter.rb" ]
	s.homepage = 'https://github.com/boazsegev/merge_pdf'
	s.license = 'GPLv3'
end
