# CombinePDF - the ruby way for merging PDF files
CombinePDF is a nifty model, written in pure Ruby, to parse PDF files and combine (merge) them with other PDF files, watermark them or stamp them (all using the PDF file format and pure Ruby code).

# Install

Install with ruby gems:
```
gem install combine_pdf
```

## Merge / Combine Pages

Combining PDF files s very straight forward.

First you create the PDF object that will contain all the combined data.

Then you "inject", using the << operator, the data - either page by page (which is slower) or file by file (which is faster).

Last, you render or save the data.

For Example:
```ruby
pdf = CombinePDF.new
# one way to combine, very fast:
pdf << CombinePDF.new "file1.pdf"
# different way to combine, slower, but allows to mix things up:
CombinePDF.new("file2.pdf").pages.each {|page| pdf << page}
# you can also parse PDF files from memory.
pdf_data = IO.read 'file3.pdf'
# we will add just the first page:
pdf << CombinePDF.parse(pdf_data).pages[0]
# Save to file
pdf.save "combined.pdf"
# or render to memory
pdf.to_pdf
```

The page by page is great if you want to mix things up, but since the "Catalog" dictionary of the PDF file  must be updated (the Catalog is an internal PDF dictionary that contains references to all the pages and the order in which they are displayed), it is slower.

## Stamp / Watermark

**has issues with specific PDF files - [please see the issue published here](https://github.com/boazsegev/combine_pdf/issues/2).**

To stamp PDF files (or data), first create the stamp from an existing PDF file.

After the stamp was created, inject to existing PDF pages.
```ruby
# load the stamp
stamp_pdf_file = CombinePDF.new "stamp_pdf_file.pdf"
stamp_page = stamp_pdf_file.pages[0]
# load the file to stamp on
pdf = CombinePDF.new "file1.pdf"
#stamping each page with the << operator
pdf.pages.each {|page| page << stamp_page}
```
 
Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages. The Page objects are Hash class objects and the << operator was added to the Page instances without altering the class.

Decryption & Filters
====================

Some PDF files are encrypted and some are compressed (the use of filters)...

There is very little support for encrypted files and very very basic and limited support for compressed files.

I need help with that.

Comments and file structure
===========================

If you want to help with the code, please be aware:

I'm a self learned hobbiest at heart. The documentation is lacking and the comments in the code are poor guidlines.

The code itself should be very straight forward, but feel free to ask whatever you want.

Credit
======

Caige Nichols wrote an amazing RC4 gem which I used in my code.

I wanted to install the gem, but I had issues with the internet and ended up copying the code itself into the combine_pdf_decrypt class file.

Credit to his wonderful is given here. Please respect his license and copyright... and mine.

License
=======
GPLv3








