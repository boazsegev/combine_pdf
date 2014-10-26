#Change Log

***

Change log v.0.1.6

**fix**: added Mutex to font library (which was shared by all PDFWriter objects) - now fonts are thread safe (PDF objects are NOT thread safe by design).

**fix**: RTL recognition did not reverse brackets, it should now correctly perform brackets reversal for any of the following: (,),[,],{,},<,>.

**update**: updated license to MIT.

**known issues**: encrypted PDF files can sometimes silently fail (producing empty pages) - this is because on an attempted decrypt. more work should be done to support encrypted PDF files. please feel fee to help.

I use this version on production, where I have control over the PDF files I use. It is beter then system calls to pdftk (which can cause all threads in ruby to hold, effectively causing my web app to hang).