#Change Log

***

Change log v.0.1.21
(pre-release)

No changes yet.

***

Change log v.0.1.20

**fix**: due to some PDF files not conforming to the required EOL marker in the endstream object specifications, the parser is now back to a non-strict parsing mode for PDF Stream Objects. Conforming files weren't found to be effected and although it is unlikely, it is possible that they might be effected if the stream object would contain the 'endstream' keyword without the required EOL marker and without intending to end the stream object.

***

Change log v.0.1.19

**fix**: merged @espinosa's fix for issue #16 which affected windows machines.

**feature**: added a #write_table method to the PDF pages, allowing tables to be written on existing PDF pages. This is a destructive method (it changes the table_data array by removing any rows written to the page and leaving the rest of the data untouched, for future writing). Read the documentation before using this method.

**update**: stricter parsing for PDF Stream Objects is now enforced. The stricter parsing is NOT final, as it walks a fine line between allowing non-conforming PDF files to be read and risking an error while reading a correctly structured file which has PDF keywords intentionaly embedded in a correctly structured object stream (keywords which would be normally ignored as expected, but which will be recognized as relevant if the parser is less strict about the structure of the PDF file).

***

Change log v.0.1.18

**fix**: Thank to Stefan, who reported issue #15 , we discovered that in some cases PDF files presented the wrong PDF standard version, causing an error while attempting to parse their data. The issue has been fixed by allowing the parser to search for PDF Object Streams even when the PDF file claims a PDF version below 1.5. 

***

Change log v.0.1.17

**feature**: Although it was possible to create and add empty PDF pages (at any location), it is now even easier with one method call to add empty pages at the end of a PDF object. It's also possible to add text to these empty pages or stamp them with different content.

**fix?**: a possible multi-threading issue might have existed where to threads saving PDF data at the same time might corrupt PDF data (although this theoretical issue was never reported and probably never encountered). The PDF streams should now be a bit more thread safe, as long as no two threads attempt to render the same PDF object at the same time.

**fix**: Thank to Georg, who reported issue #14 , we are now working on a fix of a mysterious issue with textboxes which could effect page numbering and textboxes on certain PDF files. It is unknown at this time if the issue is resolved and the fix is awaiting confirmation. The issue effected only some PDF files and not others.

***

Change log v.0.1.16

**fix?**: Compatability reports came in showing that some email servers convery new-line (\n) characters to CRLF (\r\n) - corrupting the binary code in the PDF files. This version attemps to fix this by adding more binary characters to the first comment line of the PDF file (right after the header). Most email programs and Antivirus programs should preserve the original EOL character once they recognize the file as binary.

***

Change log v.0.1.15

**features**: added new PDF#Page API to deal with page rotation and orientation. see the docs for more info.

***

Change log v.0.1.14

**changes**: changed the way the PDF Page objects are 'injected' with their methods, so that the PDF#pages method is faster and more methods can be injected into the Hash object. For instance, textbox can now be called on an existing page without creating a PDFWriter object and 'stumping' the new data.

(the number_pages method hasn't been update to use this new feature as of yet)

***

Change log v.0.1.13

**fix**: fix for Acrobat Reader compatablity (by removing color-space declarations). Should solve issue #13 , reported originaly by Imanol and Diyei Gomi.

***

Change log v.0.1.12

**fix**: fix for page rotation inheritance.

**fix**: fix for the issue was discovered while observing issue #13, reported originaly by Imanol and Diyei Gomi. The issue was probably caused by parsing errors introduced while parsing hex strings (a case sensitive method was used by mistake and this is now corrected).
***

Change log v.0.1.11

**fix**: fixed a bug where Page Resources and ColorSpace data wouldn't be inherited correctly from the Catalog and Pages parent objects. This issue could cause pages to render without all their content intact. This issue is now fixed (although more testing should be done for multiple inheritance).

**?fix?** Attempted to fix [the issue reported by srogers](https://github.com/boazsegev/combine_pdf/issues/10), by forcing all String byte collections to return an Array. waiting confirmation for fix (couldn't reproduce the issue just yet, as I can't seem to install Ruby MRI 1.9.3 on my mac).

***

Change log v.0.1.10

**fix**: fixed a typo that prevented access to the CombinePDF::VERSION constant.

***

Change log v.0.1.9

**fix**: possible fix for bug reported by lamphuongha, regarding PDF 1.5 streams. I await confirmation that the fix actually works, as I cannot seem to reproduce the whole spectrum of the bug on my system...

***

Change log v.0.1.8

**fix**: Fixed an [issue reported by Saba](https://github.com/boazsegev/combine_pdf/issues/8), where PDF files that were written using bad practices (namely, without wrapping their content streams correctly) would not be stamped correctly due to changes in the space matrix (CTM). Fixed by wrapping all existing streams before stamping.

***

Change log v.0.1.7

**fix**: PDF `insert` had a typo in the code that would cause failure when unsupported object insertion was attempted - fixed by Nathan Keyes (nkeyes).

***

Change log v.0.1.6

**fix**: added Mutex to font library (which was shared by all PDFWriter objects) - now fonts are thread safe (PDF objects are NOT thread safe by design).

**fix**: RTL recognition did not reverse brackets, it should now correctly perform brackets reversal for any of the following: (,),[,],{,},<,>.

**update**: updated license to MIT.

**known issues**: encrypted PDF files can sometimes silently fail (producing empty pages) - this is because on an attempted decrypt. more work should be done to support encrypted PDF files. please feel fee to help.

I use this version on production, where I have control over the PDF files I use. It is beter then system calls to pdftk (which can cause all threads in ruby to hold, effectively causing my web app to hang).