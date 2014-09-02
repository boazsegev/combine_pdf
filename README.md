I almost finished writing a long and wonderful readme... and then my browser decided the backspace was to go back in the page history and I lost it all!

Damn, I'm too tired to write now...

# Merge PDFs!

I started the project as a model within a RoR (Ruby on Rails) application, and as it grew I moved it to a local gem.

I fell in love with the project, even if it is still young and in the raw.

It is very simple to parse pdfs - from files:

pdf = MergePDF.new "file_name.pdf"

or from data:

pdf = MergePDF.parse "%PDF-1.4 .... [data]"

It's also easy to start an empty pdf:

pdf = MergePDF.new

Merging is a breeze:

pdf << MergePDF.new "another_file_name.pdf"

and saving the final PDF is a one-liner:

pdf.save "output_file_name.pdf"

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








