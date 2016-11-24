#Change Log

***

Change log v.0.2.32 (un-released)

**Update**: Better errors when encryption related exceptions occur. Credit to Paul Shumeika ( @pshumeika ).

**Fix**: Fixed an issue where empty pages with NULL contents value would cause CombinePDF to raise an exception when rendering. Credit to @holtmaat and Jason DeLeon (@progmem) (both in submitted different PRs regarding the issue).

***

Change log v.0.2.31

**Broke**: Broke the fix for issue #65 so that Radio buttons data might be lost... working on a fix.

**Fix**: Fixed issue #82 (reintroduction of issue #19 due to core engine rewrite) related to a workaround for an issue with AcrobatReader. Credit to @gyuchang for testing and helping with the fix.

**Merge**: Merged pull request #80, fixing an issue with byte decoding. Credit to @gyuchang for the PR.

**Performance**: Improved performance for the reference and duplicate object resolution. Credit to @gyuchang for pointing some optimization options.

***

Change log v.0.2.30

**Fix**: Fixed an issue where HTTP artifacts before the beginning of a PDF file / string would prevent the PDF from being parsed. This should fix issue #78 reported by @robvitaro.

***

Change log v.0.2.29

**Fix**: Fixed an issue where updating a page's rotation might raise a `NoMethodError` exception. Credit to Danny (@dikond) both for discovering the issue and for PR #77 that fixes this.

***

Change log v.0.2.28

**Fix**: Fixed an issue related to page stumping, which was introduced when the Rubocop beautification changed the logic of an `if` statement in the Resource merger. Credit to Leon Miller-Out (@sbleon) for noticing the issue, testing and opening PR #76.

***

Change log v.0.2.27

**Fix**: Fixed an issue where a `nil` outline count would cause PDF merger to fail.

**Fix**: Fixed an issue where `nil` data would cause the named destination rebuilding process to quit early, leaving some of the data unprocessed. Credit to Stefan Leitner (@sLe1tner) for exposing the issue.

**Feature**: PDF outlines are now merged and named destination links are preserved (both in the outlines and the page content). Credit to Stefan Leitner (@sLe1tner) for this feature.

***

Change log v.0.2.26

**Fix**: Merged PR #72, fixing a typo in the parser that caused incorrect byte substitution to corrupt certain PDF data (adversely effecting encrypted PDFs). Credit to Gyuchang Jun (@gyuchang) for the fix.

***

Change log v.0.2.25

**Fix**: Fixed issue #71, merging PDF outline that exist but have 0 entries fails and raises an exception. Credit to @Kagetsuki for exposing the issue.

***

Change log v.0.2.24

**Fix**: Fixed an issue with PDF Catalog and PDF Page property inheritance that could cause corrupted PDF output (invalid PDF data). Credit to @Kagetsuki for opening an issue that let to this discovery.

**Fix**: Fixed an issue with the parser where (ignored) empty strings would cause incorrect alignment when converting PDF dictionary objects from an Array to a Hash, mixing up keys and values. Credit to @Kagetsuki for opening an issue that let to this discovery.

**Fix**: more fixes and refinements to the PDF Names dictionary with better named destination support and document navigation support.

***

Change log v.0.2.23

**Fix**: fixed an issue introduced in v.0.2.22, where name dictionary conflict resolution would result in corrupted PDF files. The issue was caused because the name conflict resolution wasn't updated to handle the changes in the new reference linking algorithm used by the parser. During this fix, the whole name dictionary algorithm was re-written, providing better support for named destinations, links and (future feature) ToCs. Credit to Kevin Shen (@kevshin2) for exposing the issue.

***

Change log v.0.2.22 (yanked)

**Fix**: fixed an issue with PDF font importing (registering).

**Fix**: fixed issue #65 where some form data (radio buttons) could be lost. Credit to @joshirashmics for exposing the issue.

**Fix**: fixed an issue where empty names would be ignored by the parser (who knew they existed...).

**Fix**: Possible fix for issue #66 (similar to PR #61)... Credit to Serafeim Maroulis (@Reyko) and Kevin Shen (@kevshin2) for exposing the issue.

**Update**: Rewrote some internal algorithms, avoiding recursive logic and optimizing against excessive stack stress.

**Feature**: Credit to Joel Williams (@joelw) for providing `CombinePDF.load` and `CombinePDF.parse` customization, allowing optional content errors to be ignored - taking the risk of a corrupt PDF instead of raising an exception (hey, loading PDF data with optional content sometimes works).

***

Change log v.0.2.21

**Fix**: fix for issue #54 and #59 (duplicate), discovered by @iggant (Anton Kolodii), related to name conflict resolution and page resources. The issue would cause and error (exception) to occur when attempting to merge pages with specific resource structures. Credit to @cw6365 (Chris Ward) and @DenKey (Den) as well.

***

Change log v.0.2.20

**Fix**: fix for issue #56, discovered by @LeptonHeavy, regarding errors caused by the new PDF form support feature.

***

Change log v.0.2.19 (yanked)

**Partial fix**: unconfirmed fix for issue #56, discovered by @LeptonHeavy, regarding errors caused by the new PDF form support feature.

***

Change log v.0.2.18 (yanked)

**Feature**: added minor (read: initial and incomplete) PDF forms support, in an attempt to preserve form data when combining PDF files.

***

Change log v.0.2.17

**Feature**: added the `page#crop` method to easily crop a PDF file in accordance with the GWG industry association recommendations (updating the `MediaBox` property rather then the `CropBox`). Credit to @wingleungchoi for this feature.

***

Change log v.0.2.16

**Fix**: Fix for issue #49 where specific PDF files containing junk data after the %%EOF marker couldn't be opened (as they were invalid files). The issue was fixed by scanning any trailing data before continuing to parse any PDF file beyond the first %%EOF markers (multiple markers are common when using the PDF format). Credit to @wingleungchoi for providing an example for the issue.

***

Change log v.0.2.15

**Fix**: Fix for issue #22 where specific PDF files with nested references could cause page stamping to fail, raising an exception. Credit to @tomascharad for finding the issue.

***

Change log v.0.2.14

**Fix**: Fix for issue #39, where certain comments could have caused the object after the comments to be ignored, resulting in parsing errors. Credit to @lgn21st for identifying the issue.

***

Change log v.0.2.13

**Fix** fixed issue # 37 reported by @sega (thank you for reporting!), regarding the insability to stamp one PDF page over another when one PDF page used a resource directory propegated with data and another page used a resource directory propegated with references. This was now resolved by checking for references before merging the data.

**Compatability**: fixed an issue where PrimoPDF would ommit the required EOL marker before the `endstream`. This would cause malformed PDF files to be written and it is now resolved by allowing the required EOL to be optional.

**Minor**: a minor improvement on the compatability fix related to salvaging PDF data that was misplaced within a PDF comment. This improvement relates to the possibility that there might not be an EOL marker after the `obj` keyword (PaperPort does use an EOL after the `obj` keyword, so this isn't critical).

***

Change log v.0.2.12

**Compatability**: fixed issue #36 reported by @vitstradal (thank you for reporting!) regarding PDF files composed by PaperPort. PaperPort (at least version 12) has an issue where PDF data will be placed within a PDF comment. PDF comments start with a "%" sign and end with an EOL marker ("\r" or "\n"). PaperPort ommitted the EOL marker, placing critical data within the comment. A work-around was found by parsing the comment's data and attempting to salvage the misplaced data. This workaround assumes that comments would not contain PDF parsable data at the very end of the comment's line... which is an unsafe assumption. hence, **please let me know if you find _any_ PDF files that worked before the workaround was introduced**.

***

Change log v.0.2.11

**Fix**: fix for issue #35 , which was caused by the broken fix for issue #34. Credit to Davek Rupinski for pointing out the issue.

***

Change log v.0.2.10

**Fix**: fixed page stamping when the page's content was a referenced object instead or a direct array of content references. Credit to vitstradal for discovering the issue.

***

Change log v.0.2.9

**Fix** hopefully fixed issue #33 ([NoMethodError undefined method `[]` for nil:NilClass](https://github.com/boazsegev/combine_pdf/issues/33)).

***

Change log v.0.2.8

* **Fix/Feature**: (related to [issue #32](https://github.com/boazsegev/combine_pdf/issues/32))

     Experience shows that it's very difficult to know when to use `page.copy` v.s. `page.copy(true)` before stamping one pdf pages on top (or under) another... So...

     Now there is no longer any need for the guesswork. The process is automated for you.

     The moment CombinePDF recognizes a resource name conflice between two pages (such as both pages using one font name to reference two different fonts), CombinePDF will intrusively rename the incoming page's resources.

     It is true that the intrusive resource renaming is somewhat risky and might require the inflation of some comperssed page data (resulting in bigger file sizes), but this is the only way to attempt and prevent PDF data curruption.

***

Change log v.0.2.7

**Fix**: Fixed an issue where a malformed PDF String could cause the parser to hang.

**Update**: Inner PDF links (links to pages within the PDF file) will now be preserved when importing a whole PDF (although Outlines, for now, are discarede and their related links will be discarded as well). If the same destination page is inserted more than once (the first version will be preferred).

**Deprecation Warning**: the `Page_Methods#secure_injection`, `Page_Methods#make_unsecure` and `Page_Methods#make_secure` methods are deprecated. Use `Page_Methods#copy(true)` for safeguarding against font/resource conflicts when "stamping" one PDF page over another.

***

Change log v.0.2.6

**fixed**: Hasan Iskandar fixed issue #30 - Output file cannot be saved from Adobe Reader with "Save As optimizes for Fast Web View" preference enabled. Thank you Hasan.

**update**: More parsing error detection; Updated the endstream EOL marker indentifier for safer indentification.

***

Change log v.0.2.5

**feature**: circumvents an issue with 'wkhtmltopdf', where sometimes the `endobj` keyword would be missing, causing malformed PDF data. The parser will now attempt to auto-fix any `endobj` missing keywords.

**semi-fix**: make sure decryption is attempetd using actual values (vs. references). The code was updated for a similar result as should have been achived before.

***

Change log v.0.2.4

**fixed**: Fixed the default page sizes which weren't as described in the documentation and now default to US Letter. The documentation was also fixed. No major version bump is declered since the defaults were faulty and weren't as described (fixed a bug, not changed the API).

**feature**: added the `resize` page method, to allow resizing of pages with or without conserving the content's aspect ratio (defaults to conserving the aspect ratio).

***

Change log v.0.2.3

**update**: a better general error message for CombinePDF.new

**fix**: the `make_secure` now correctly sets the secure copy flag, as expected. For performance reasons it is better to use page.copy(true) for renaming conflicting resource identifiers, but if multiple secure copies are needed for some reason, using `make_secure` will now make sure each copy is secured independently.

**fix**: the secure copy now worked as expected (it had issue with referenced resource dictionaries that was resolved by following the references).

**fix**: fixed an object numbering issue introduced by duplicating pages as part of the Adobe Reader bug workaround. The issue was thought to have been fixed before but some PDF structures were not proprly addressed.

***

Change log v.0.2.2

**fix**: fixed the default value for the :location attribute of PDF#stamp_pages(String, options). Now, instead of the default stamp being written at [:top, :bottom], it's default location will be set to [:center].

**fix**: fixed the 'center' location in the page numbering, so that it wouldn't enforce a small font on an all page centered number.

***

Change log v.0.2.1

**fix**: better page stamping... or, at least more secure (we hope).

**feature**: added the PDF#stamp_pages shortcut method. Credit to Tania (@taniarv) for the concept.

**fix**: possible string encoding issues could have arose when strings were rendered to PDF format. Credit to Tania (@taniarv) for exposing the issue.

**feature**: Metadata is now easier to set by allowing fast access to the Information header when using PDF#save and PDF#to_pdf. Credit to Tania (@taniarv) for code.

***

Change log v.0.2.0

Refractoring of code and API overhall.

Any code relying on inner/advanced API calls might be broken.

**fix**: fixed an object numbering issue introduced by duplicating pages. The issue didn't seem to effect readers nor performance.

**fix**: combine_pdf will now properly raise an error when Optional Content Groups (OCG's) are implemented in a PDF file. Page extraction isn't supported for PDF files with OCG's.

***

Change log v.0.1.23

**fix**: @kruszczynski fixed an issue with CombinePDF::PDF#number_pages where the page numbering margines were ignored and only the default values were used. Thank you @kruszczynski .

***

Change log v.0.1.22

**fix**: a tested fix for issue #19, where Acrobat Reader would raise an error if page objects in the Catalog were copied by reference instead of copied in full and each was assigned different a unique object id. (possibly an Acrobat Reader Issue workaround) The issue was resolved by exempting page objects from the duplication reduction algorithm, and in this way, forcing duplicates to be copied rather then referenced in the Catalog object.

***

Change log v.0.1.21

**fix**: an attempted fix for issue #19, where the xref table wasn't read on Acrobat Reader, probably due to a double EOL marker at the end of each entry.

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
