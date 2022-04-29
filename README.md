# CombinePDF - the ruby way for merging PDF files
[![Gem Version](https://badge.fury.io/rb/combine_pdf.svg)](http://badge.fury.io/rb/combine_pdf)
[![GitHub](https://img.shields.io/badge/GitHub-Open%20Source-blue.svg)](https://github.com/boazsegev/combine_pdf)
[![Documentation](http://inch-ci.org/github/boazsegev/combine_pdf.svg?branch=master)](https://www.rubydoc.info/github/boazsegev/combine_pdf)
[![Maintainers Wanted](https://img.shields.io/badge/maintainers-wanted-red.svg)](https://github.com/pickhardt/maintainers-wanted)


CombinePDF is a nifty model, written in pure Ruby, to parse PDF files and combine (merge) them with other PDF files, watermark them or stamp them (all using the PDF file format and pure Ruby code).

## Install

Install with ruby gems:

```ruby
gem install combine_pdf
```

## Help Wanted

I need help maintaining the CombinePDF Ruby gem.

I wrote this gem because I needed to solve an issue with bates-numbering existing PDF documents. However, during the last three years or so I have been maintaining the project for no reason at all, except that I enjoyed sharing it with the community.

I love this gem, but I feel it's time I took a step back from maintaining it and concentrate on my music and other things I want to develop.

Please hit me up if you would like to join in and eventually take over.

## Known Limitations

Quick rundown:

* When reading PDF Forms, some form data might be lost. I tried fixing this to the best of my ability, but I'm not sure it all works just yet.

* When combining PDF Forms, form data might be unified. I couldn't fix this because this is how PDF forms work (filling a field fills in the data in any field with the same name), but frankly, I kinda liked the issue... it's almost a feature.

* When unifying the same TOC data more than once, one of the references will be unified with the other (meaning that if the pages look the same, both references will link to the same page instead of linking to two different pages). You can fix this by adding content to the pages before merging the PDF files (i.e. add empty text boxes to all the pages).

* Some links and data (URL links and PDF "Named Destinations") are stored at the root of a PDF and they aren't linked back to the page. Keeping this information requires merging the PDF objects rather than their pages.

    Some links will be lost when ripping pages out of PDF files and merging them with another PDF.

* Some encrypted PDF files (usually the ones you can't view without a password) will fail quietly instead of noisily.

* Sometimes the CombinePDF will raise an exception even if the PDF could be parsed (i.e., when PDF optional content exists)... I find it better to err on the side of caution, although for optional content PDFs an exception is avoidable using `CombinePDF.load(pdf_file, allow_optional_content: true)`.

* The CombinePDF gem runs recursive code to both parse and format the PDF files. Hence, PDF files that have heavily nested objects, as well as those that where combined in a way that results in cyclic nesting, might explode the stack - resulting in an exception or program failure.

CombinePDF is written natively in Ruby and should (presumably) work on all Ruby platforms that follow Ruby 2.0 compatibility.

However, PDF files are quite complex creatures and no guarantee is provided.

For example, PDF Forms are known to have issues and form data might be lost when attempting to combine PDFs with filled form data (also, forms are global objects, not page specific, so one should combine the whole of the PDF for any data to have any chance of being preserved).

The same applies to PDF links and the table of contents, which all have global attributes and could be corrupted or lost when combining PDF data.

If this library causes loss of data or burns down your house, I'm not to blame - as pointed to by the MIT license. That being said, I'm using the library happily after testing against different solutions.

## Combine/Merge PDF files or Pages

To combine PDF files (or data):

```ruby
pdf = CombinePDF.new
pdf << CombinePDF.load("file1.pdf") # one way to combine, very fast.
pdf << CombinePDF.load("file2.pdf")
pdf.save "combined.pdf"
```

Or even a one liner:

```ruby
(CombinePDF.load("file1.pdf") << CombinePDF.load("file2.pdf") << CombinePDF.load("file3.pdf")).save("combined.pdf")
```

you can also add just odd or even pages:

```ruby
pdf = CombinePDF.new
i = 0
CombinePDF.load("file.pdf").pages.each do |page|
  i += 1
  pdf << page if i.even?
end
pdf.save "even_pages.pdf"
```

notice that adding all the pages one by one is slower than adding the whole file.
## Add content to existing pages (Stamp / Watermark)

To add content to existing PDF pages, first import the new content from an existing PDF file. After that, add the content to each of the pages in your existing PDF.

In this example, we will add a company logo to each page:

```ruby
company_logo = CombinePDF.load("company_logo.pdf").pages[0]
pdf = CombinePDF.load "content_file.pdf"
pdf.pages.each {|page| page << company_logo} # notice the << operator is on a page and not a PDF object.
pdf.save "content_with_logo.pdf"
```

Notice the << operator is on a page and not a PDF object. The << operator acts differently on PDF objects and on Pages.

The << operator defaults to secure injection by renaming references to avoid conflicts. For overlaying pages using compressed data that might not be editable (due to limited filter support), you can use:

```ruby
pdf.pages(nil, false).each {|page| page << stamp_page}
```

## Page Numbering

adding page numbers to a PDF object or file is as simple as can be:

```ruby
pdf = CombinePDF.load "file_to_number.pdf"
pdf.number_pages
pdf.save "file_with_numbering.pdf"
```

Numbering can be done with many different options, with different formatting, with or without a box object, and even with opacity values - [see documentation](https://www.rubydoc.info/github/boazsegev/combine_pdf/CombinePDF/PDF#number_pages-instance_method).

For example, should you prefer to place the page number on the bottom right side of all PDF pages, do:

```ruby
pdf.number_pages(location: [:bottom_right])
```

As another example, the dashes around the number are removed and a box is placed around it. The numbering is semi-transparent and the first 3 pages are numbered using letters (a,b,c) rather than numbers:


```ruby
# number first 3 pages as "a", "b", "c"
pdf.number_pages(number_format: " %s ",
                 location: [:top, :bottom, :top_left, :top_right, :bottom_left, :bottom_right],
                 start_at: "a",
                 page_range: (0..2),
                 box_color: [0.8,0.8,0.8],
                 border_color: [0.4, 0.4, 0.4],
                 border_width: 1,
                 box_radius: 6,
                 opacity: 0.75)
# number the rest of the pages as 4, 5, ... etc'
pdf.number_pages(number_format: " %s ",
                 location: [:top, :bottom, :top_left, :top_right, :bottom_left, :bottom_right],
                 start_at: 4,
                 page_range: (3..-1),
                 box_color: [0.8,0.8,0.8],
                 border_color: [0.4, 0.4, 0.4],
                 border_width: 1,
                 box_radius: 6,
                 opacity: 0.75)
```

    pdf.number_pages(number_format: " %s ", location: :bottom_right, font_size: 44)


## Loading and Parsing PDF data

Loading PDF data can be done from file system or directly from the memory.

Loading data from a file is easy:

```ruby
pdf = CombinePDF.load("file.pdf")
```

You can also parse PDF files from memory. Loading from the memory is especially effective for importing PDF data received through the internet or from a different authoring library such as Prawn:

```ruby
pdf_data = prawn_pdf_document.render # Import PDF data from Prawn
pdf = CombinePDF.parse(pdf_data)
```

Using `parse` is also effective when loading data from a remote location, circumventing the need for unnecessary temporary files. For example:

```ruby
require 'combine_pdf'
require 'net/http'

url = "https://example.com/my.pdf"
pdf = CombinePDF.parse Net::HTTP.get_response(URI.parse(url)).body
```

## Rendering PDF data

Similarly, to loading and parsing, rendering can also be performed either to the memory or to a file.

You can output a string of PDF data using `.to_pdf`. For example, to let a user download the PDF from either a [Rails application](http://rubyonrails.org) or a [Plezi application](http://www.plezi.io):

```ruby
# in a controller action
send_data combined_file.to_pdf, filename: "combined.pdf", type: "application/pdf"
```

In [Sinatra](http://www.sinatrarb.com):

```ruby
# in your path's block
status 200
body combined_file.to_pdf
headers 'content-type' => "application/pdf"
```


If you prefer to save the PDF data to a file, you can always use the `save` method as we did in our earlier examples.

Some PDF files contain optional content sections which cannot always be merged reliably. By default, an exception is
raised if one of these files are detected. You can optionally pass an `allow_optional_content` parameter to the
`PDFParser.new`, `CombinePDF.load` and `CombinePDF.parse` methods:

```ruby
new_pdf = CombinePDF.new
new_pdf << CombinePDF.load(pdf_file, allow_optional_content: true)
attachments.each { |att| new_pdf << CombinePDF.load(att, allow_optional_content: true) }
```

Demo
====

You can see a Demo for a ["Bates stumping web-app"](http://combine-pdf-demo.herokuapp.com/bates) and read through it's [code](https://github.com/boazsegev/combine_pdf_demo/blob/c9914588e4116dcfdaa37f85727f442b064e2b04/pdf_controller.rb) . Good luck :)

Decryption & Filters
====================

Some PDF files are encrypted and some are compressed (the use of filters)...

There is very little support for encrypted files and very very basic and limited support for compressed files.

I need help with that.

Comments and file structure
===========================

If you want to help with the code, please be aware:

I'm a self learned hobbyist at heart. The documentation is lacking and the comments in the code are poor guidelines.

The code itself should be very straightforward, but feel free to ask whatever you want.

Credit
======

Stefan Leitner (@sLe1tner) wrote the outline merging code supporting PDFs which contain a ToC.

Caige Nichols wrote an amazing RC4 gem which I used in my code.

I wanted to install the gem, but I had issues with the internet and ended up copying the code itself into the combine_pdf_decrypt class file.

Credit for his wonderful work is given here. Please respect his license and copyright... and mine.

License
=======
MIT

Contributions
=======

You can look at the [GitHub Issues Page](https://github.com/boazsegev/combine_pdf/issues) and see the ["help wanted"](https://github.com/boazsegev/combine_pdf/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) tags.

If you're thinking of donations or sending me money - no need. This project can sustain itself without your money.

What this project needs is the time given by caring developers who keep it up to date and fix any documentation errors or issues they notice ... having said that, gifts (such as free coffee or iTunes gift cards) are always fun. But I think there are those in real need that will benefit more from your generosity.
