I almost finished writing a long and wonderful readme... and then my browser decided the backspace was to go back in the page history and I lost it all!

Damn, I'm too tired to write now...

# Merge PDFs!

I started the project as a model within a RoR (Ruby on Rails) application, and as it grew I moved it to a local gem.

I fell in love with the project, even if it is still young and in the raw.

It is very simple to parse pdfs - from files:
```ruby
pdf = MergePDF.new "file_name.pdf"
```
or from data:
```ruby
pdf = MergePDF.parse "%PDF-1.4 .... [data]"
```
It's also easy to start an empty pdf:
```ruby
pdf = MergePDF.new
```
Merging is a breeze:
```ruby
pdf << MergePDF.new "another_file_name.pdf"
```
and saving the final PDF is a one-liner:
```ruby
pdf.save "output_file_name.pdf"
```

Also, as a side effect, we can get all sorts of info about our pdf... such as the page count:
```ruby
pdf.version # will tell you the PDF version (if discovered). you can also reset this manually.
pdf.pages.length # will tell you how much pages are actually displayed
pdf.all_pages.length # will tell you how many page objects actually exist (can be more or less then the pages displayed)
pdf.info_object # a hash with the Info dictionary from the PDF file (if discovered).
```


# Stamp PDF files

**has issues with specific PDF files - please see the issues**: https://github.com/boazsegev/merge_pdf/issues/2 

You can use PDF files as stamps.

For instance, lets say you have this wonderful PDF (maybe one you created with prawn), and you want to stump the company header and footer on every page.

So you created your Prawn PDF file (Amazing library and hard work there, I totally recommend to have a look @ https://github.com/prawnpdf/prawn ):
```ruby
prawn_pdf = Prawn::Document.new
...(fill your new PDF with goodies)...
```
Stamping every page is a breeze.

We start by moving the PDF created by prawn into a MergePDF object.
```ruby
pdf = MergePDF.parse prawn_pdf.render
```

Next we extract the stamp from our stamp pdf template:
```ruby
pdf_stamp = MergePDF.new "stamp_file_name.pdf"
stamp_page = pdf_stamp.pages[0]
```

And off we stamp each page:
```ruby
pdf.pages.each {|page| pages << stamp_page}
```

Of cource, we can save the stamped output:
```ruby
pdf.save "output_file_name.pdf"
```


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

I wanted to install the gem, but I had issues with the internet and ended up copying the code itself into the merge_pdf_decrypt class file.

Credit to his wonderful is given here. Please respect his license and copyright... and mine.

License
=======
GPLv3








