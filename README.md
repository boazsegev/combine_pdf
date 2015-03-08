# CombinePDF - the ruby way for merging PDF files
CombinePDF is a nifty model, written in pure Ruby, to parse PDF files and combine (merge) them with other PDF files, watermark them or stamp them (all using the PDF file format and pure Ruby code).

# Install

Install with ruby gems:

```ruby
gem install combine_pdf
```

## Combine/Merge PDF files or Pages

To combine PDF files (or data):

```ruby
pdf = CombinePDF.new
pdf << CombinePDF.new("file1.pdf") # one way to combine, very fast.
pdf << CombinePDF.new("file2.pdf")
pdf.save "combined.pdf"
```

Or even a one liner:

```ruby
(CombinePDF.new("file1.pdf") << CombinePDF.new("file2.pdf") << CombinePDF.new("file3.pdf")).save("combined.pdf")
```

you can also add just odd or even pages:

```ruby
pdf = CombinePDF.new
i = 0
CombinePDF.new("file.pdf").pages.each do |page|
  i += 1
  pdf << page if i.even?
end
pdf.save "even_pages.pdf"
```

notice that adding all the pages one by one is slower then adding the whole file.
## Add content to existing pages (Stamp / Watermark)

To add content to existing PDF pages, first import the new content from an existing PDF file. After that, add the content to each of the pages in your existing PDF.

In this example, we will add a company logo to each page:

```ruby
company_logo = CombinePDF.new("company_logo.pdf").pages[0]
pdf = CombinePDF.new "content_file.pdf"
pdf.pages.each {|page| page << company_logo} # notice the << operator is on a page and not a PDF object.
pdf.save "content_with_logo.pdf"
```

Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages.

The << operator defaults to secure injection by renaming references to avoid conflics. For overlaying pages using compressed data that might not be editable (due to limited filter support), you can use:

```ruby
pdf.pages(nil, false).each {|page| page << stamp_page}
```

## Page Numbering

adding page numbers to a PDF object or file is as simple as can be:

```ruby
pdf = CombinePDF.new "file_to_number.pdf"
pdf.number_pages
pdf.save "file_with_numbering.pdf"
```

Numbering can be done with many different options, with different formating, with or without a box object, and even with opacity values - see documentation.

## Loading PDF data

Loading PDF data can be done from file system or directly from the memory.

Loading data from a file is easy:

```ruby
pdf = CombinePDF.new("file.pdf")
```

you can also parse PDF files from memory:

```ruby
pdf_data = IO.read 'file.pdf' # for this demo, load a file to memory
pdf = CombinePDF.parse(pdf_data)
```

Loading from the memory is especially effective for importing PDF data recieved through the internet or from a different authoring library such as Prawn.

Demo
====

You can see a Demo for a ["Bates stumping web-app"](http://combine-pdf-demo.herokuapp.com/bates) and read through it's [code](http://combine-pdf-demo.herokuapp.com/code) . Good luck :)

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
MIT
