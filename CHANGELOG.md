# Change Log

#### Change log v.1.0.31 (2025-04-03)

**Fix**: RangeError: index out of range errors occurred with some malformed PDFs, when the number of bytes in a PDF `stream` didn't match the number of bytes expected according to the `Length` property. Credit to @Laykou and others for opening multiple issues (i.e., #205), as well as @julitrows, @mtwzim, and @Kaiito630, for pushing on this.

**Fix**: frozen string literal lingering issues. Credit to @pauline-koch, @qdegraeve, @isaporto, @ncreuschling, @francescob, @@anthonykaufman and @ma-matsui for their input on this issue. Credit to @anthonykaufman for offering one possible solution and @Markus-Munk-Shipmondo for pushing on this. Credit to @mfazekas for opening PR #215 and for @RBIII, @juliolinarez, and @osvaldoalvaradodev for supporting it.

**Fix**: possible permission issues. Credit to @davidwessman, @visini, @sander-deryckere, and @LindseySaari for exploring this.

**Fix**: calling CombinePDF.parse with a frozen string literal. Credit to @lovro-bikic for offering one possible solution.

**Fix**: Ruby 3.4 warning. Credit to @chaadow for offering one possible solution.

#### Change log v.1.0.29 (2024-12-07)

**Fix**: frozen string literal support fix. Credit to @francescob (Francesco) for PR #245.

#### Change log v.1.0.28 (2024-11-12)

**Fix**: use `require` to load code (instead of `load`). Credit to @casperisfine (Jean byroot Boussier) for PR #216.

#### Change log v.1.0.27 (2024-11-10)

**Performance**: fix performance issues with `object_id` usage in Ruby 3+. Credit to @amomchilov (Alexander Momchilov) for PR #241.

**Performance**: use frozen string literals. Credit to @casperisfine (Jean byroot Boussier) for PR #239.

#### Change log v.1.0.26 (2023-12-22)

**Performance**: possible performance bump. Credit to @denislavski (Denislav Naydenov) for opening PR #235.

#### Change log v.1.0.25 (2023-12-19)

**Fix**: possible improve memory usage. Credit to @denislavski (Denislav Naydenov) for opening PR #233 and suggesting this change.

#### Change log v.1.0.24 (2023-10-19)

**Fix**: possible `nil` in loop. Credit to @jkowens for PR #231 and adding a quick fix using a simple guard.

**Fix**: preserve file creation date metadata where relevant.

#### Change log v.1.0.23 (2023-04-04)

**Feature**: merged PR #177 for the `raise_on_encrypted: true` option support. Credit to @leviwilson and @kimyu92 for the PR.

#### Change log v.1.0.22

**Fix**: fix `fonts` dereferencing issue (#203), credit to @MarcWeber (Marc Weber) for identifying the issue.

**Fix**: fix `metrix` dependency, credit to @casperisfine (Jean byroot Boussier) for PR #195.

#### Change log v.1.0.21

**Fix**: possible fix for issue #184, where nested PDF files within an object stream could break the parser. Credit to Greg Sparrow (@hazelsparrow) for exposng the issue.

#### Change log v.1.0.20

**Fix**: merges PR #180, `TypeError: can't dup NilClass`. Credit to Adam Trepanier (@adam-e-trepanier) for the merge.

#### Change log v.1.0.19

**Fix**: fixes font height and width detection issue. Issue #179. Credit to @5anchezzz for opening the issue.

**Fix**: fixes an indentation warning. Issue #173. Credit to @rubyFeedback for exposing this issue.

#### Change log v.1.0.18

**Fix**: fixed issue with the 1.0.17 release where `ProcSet` PDF Arrays should have been expected but where ignored and a PDF Object was assumed instead (issue #171) - credit to @chuchiperriman (Jesús Barbero Rodríguez).

#### Change log v.1.0.17

NB: yanked from RubyGems.org.

**Fix**: fixed issue where nested structure equality tests might provide false positives, resulting in lost data (issue #166) - credit to @cschilbe (Conrad Schilbe).

#### Change log v.1.0.16

**Fix**: some documentation typos were fixed (PR #147) - credit to @djhopper01 (Derek Hopper).

#### Change log v.1.0.15

**Fix**: An attempt to fix JRuby compatibility concerns (issue #127).

#### Change log v.1.0.14

**Fix**: Fixed an issue related to PDF XRef table data, where a malformed EOL marker would cause the parser to fail. Credit to @dangerous (David Rainsford) for exposing this issue in a comment to issue #140.

#### Change log v.1.0.13

**Fix**: Fixed an issue related to PDF object streams (version 1.6) where a numerical object at the beginning of the stream might be mis-parsed as an object reference number rather than an object. Credit to @Defoncesko for reporting issue #141.

#### Change log v.1.0.12

**Fix**: Fixed an issue introduced in version 1.0.11, where a fragmented XREF table might cause the CombinePDF::Parser to fail. Credit to @solasdev for reporting issue #140.

#### Change log v.1.0.11

**Fix**: Fixed an issue where small floating point numbers would produce invalid PDF rendering (where exponent notation was used instead of decimal notation). Credit to @avit (Andrew Vit) for PR #139.

#### Change log v.1.0.10

**Fix**: Fixed an issue related to issue #131 where parsing would fail if the `xref` section appears to be misplaced within the PDF. Credit to @bharat303 (Bharat Godhani) for exposing this issue.

#### Change log v.1.0.9

**Fix**: Fixed issue #136 where the `#fix_rotation` function would rotate the page to the wrong direction. Credit to @dmkash for exposing this issue.

#### Change log v.1.0.8

**Fix**: Fixed an issue with octal representation in escaped string data. The issue would (usually) go unnoticed (altering internal labels in a non-disruptive manner), however the issue did effect `ColorSpace` data in the rare use of `ICCBased` color maps, causing color distortion and transparency loss. Credit to @react-rails and @bedaronco for exposing the issue (issue #130).

**Fix**: Fixed an issue with non English alphabet in PDF literal strings. This issue went undetected since PDF literal strings aren't used by CombinePDF except for the date stamping...

**Fix**: Improbable, but possibly a fix for issue #127, where the JRuby interpreter would fail to pass the correct arguments to the Hash update Proc. Since I'm trying to author a workaround, I have my doubts... but an attempt is better than nothing.

**Update**: Improved parsing error handling, courtesy of Evgeny Garlukovich (@evgenygarl).

**Update**: Added reader methods for the `names` and `outlines` PDF objects in response to issue #133. Use with care.

#### Change log v.1.0.7

**Fix**: Fix an issue where page property inheritance might break PDF structure if there's a conflict between property types (inheritance using properties by reference vs. nested properties), fixing issue #124. Credit to @erikaxel for exposing the issue.

#### Change log v.1.0.6

**Fix**: Fix warnings, issue #120. Credit to @lloeki for exposing the issue.

**Fix**: Fix / add adjustable nesting protection, fixing issue #117. Credit to @emmanuelmillionaer for exposing the issue.

#### Change log v.1.0.5

**Fix**: Fix issue #116 where some PDF objects (the page catalog and some root information data) were written twice to the saved PDF file (or String). Credit to @albertsaave  for exposing the issue using GhostScript.

***

#### Change log v.1.0.4

**Fix**: Fix issue #115 where PDF object versioning was being assumed to update the `indirect generation number`, allowing Object Streams to be inflated at the end of the parsed data collection instead of the middle. Fixed the issue by pre-emptive object deletion and by inflating Object Streams in place. Credit to @joshirashmics for exposing the issue.

***

#### Change log v.1.0.3

**Fix**: Fix issue #111 where some fonts would cause `pdf.fonts` to break the PDF. Credit to Pavel Slabý (@paulslaby) for exposing the issue.

***

#### Change log v.1.0.2

**Fix**: Fix NilError when calling `fonts` for a page that has no fonts. Credit to Pavel Slabý (@paulslaby) for PR#110.

**Fix**: Fix issue #109 where nested differences between objects weren't detected properly, causing loss of data if objects (specifically images that use image masks) would merge. The fix implements a manual equality checks with up to three (3) levels of recursion, protecting against stack overflow that can be caused by the combinations of complex PDF files and Ruby's limitless recursion on `eql?`. Credit to Ryan Scott (@Subtletree) exposing the issue.

***

#### Change log v.1.0.1

**Compatibility**: Some PDF authoring systems (namely the "Microsoft Reporting Services") produce a non-standard extra white-space after the keyword `stream`. This update should provide a compatibility fix for these occurences. Credit to @ilasorsa for exposing the issue.

***

#### Change log v.1.0.0

**Fix**: Fixed a possible issue with string corruption... it might have only existed in the development version, I'm not sure, but it's fixed anyway.

**Fix** (degrade): Fixed an issue related to deeply nested objects causing unreasonable slowdowns. The issue was resolved by degrading the PDF optimization process to review object with `stream` data instead of reviewing every object. This means more duplicate objects might be observed when similar PDF files are merged.

**Fix**: Fixed an issue related to form data where font information was lost during the PDF optimization process.

**Fix**: Fixed issue #108 by adding support for PDFs that have spaces and missing zeros in their hex encoded strings. Credit to @emmanuelmillionaer.

***

#### Change log v.0.2.37

**Fix**: Fixed `Page_Methods#textbox` default `:x`,`:y` to allow for non-zero/cropped page origin. Credit to @donnguyen for exposing the issue.

**Fix**: Fix typo on Parser error message for general parser error. Credit to @axlekb.

***

#### Change log v.0.2.36

**Fix**: Fix for [issue #104](https://github.com/boazsegev/combine_pdf/issues/104). Credit to @tomascharad for exposing the issue.

**Release**: This gem had been using a development versioning scheme for far too long. The API is stable enough to switch to a production versioning scheme. This version is expected to be the last 0.x version. Assuming this version will be stable enough, it is expected to be re-released as v.1.0.


***

#### Change log v.0.2.35

**Update**: Updated / upgraded our RC4 and AES PDF encryption support (for non-password protected PDFs). Credit to Gyuchang Jun (@gyuchang) for his work on providing CombinePDF with this extra encryption support. I have no idea what magic he used to make this happen, but it's beautiful!


***

#### Change log v.0.2.34

**Fix**: [fixed issue #44 for wkhtmltopdf compatibility](https://github.com/boazsegev/combine_pdf/issues/44) and PDF v.1.2 use of named destinations. Credit to Devin Wadsworth (@daymun) for exposing the issue.

***

#### Change log v.0.2.33

**Update**: Fix #97 to allow javascript support for interactive objects. Credit to @joshirashmics for exposing the issue.

**Update**: Extended "named tree" support now preserves some advanced PDF feature that weren't supported before.

**Deprecation**: Ruby is deprecating `Fixnum`, as so is CombinePDF... replaced all `Fixnum` occurrences with `Integer`.

***

#### Change log v.0.2.32

**Update**: Better errors when encryption related exceptions occur. Credit to Paul Shumeika ( @pshumeika ).

**Fix**: Fixed an issue where empty pages with NULL contents value would cause CombinePDF to raise an exception when rendering. Credit to @holtmaat and Jason DeLeon (@progmem) (both in submitted different PRs regarding the issue).

***

#### Change log v.0.2.31

**Broke**: Broke the fix for issue #65 so that Radio buttons data might be lost... working on a fix.

**Fix**: Fixed issue #82 (reintroduction of issue #19 due to core engine rewrite) related to a workaround for an issue with AcrobatReader. Credit to @gyuchang for testing and helping with the fix.

**Merge**: Merged pull request #80, fixing an issue with byte decoding. Credit to @gyuchang for the PR.

**Performance**: Improved performance for the reference and duplicate object resolution. Credit to @gyuchang for pointing some optimization options.

***

#### Change log v.0.2.30

**Fix**: Fixed an issue where HTTP artifacts before the beginning of a PDF file / string would prevent the PDF from being parsed. This should fix issue #78 reported by @robvitaro.

***

#### Change log v.0.2.29

**Fix**: Fixed an issue where updating a page's rotation might raise a `NoMethodError` exception. Credit to Danny (@dikond) both for discovering the issue and for PR #77 that fixes this.

***

#### Change log v.0.2.28

**Fix**: Fixed an issue related to page stumping, which was introduced when the Rubocop beautification changed the logic of an `if` statement in the Resource merger. Credit to Leon Miller-Out (@sbleon) for noticing the issue, testing and opening PR #76.

***

#### Change log v.0.2.27

**Fix**: Fixed an issue where a `nil` outline count would cause PDF merger to fail.

**Fix**: Fixed an issue where `nil` data would cause the named destination rebuilding process to quit early, leaving some of the data unprocessed. Credit to Stefan Leitner (@sLe1tner) for exposing the issue.

**Feature**: PDF outlines are now merged and named destination links are preserved (both in the outlines and the page content). Credit to Stefan Leitner (@sLe1tner) for this feature.

***

#### Change log v.0.2.26

**Fix**: Merged PR #72, fixing a typo in the parser that caused incorrect byte substitution to corrupt certain PDF data (adversely effecting encrypted PDFs). Credit to Gyuchang Jun (@gyuchang) for the fix.

***

#### Change log v.0.2.25

**Fix**: Fixed issue #71, merging PDF outline that exist but have 0 entries fails and raises an exception. Credit to @Kagetsuki for exposing the issue.

***

#### Change log v.0.2.24

**Fix**: Fixed an issue with PDF Catalog and PDF Page property inheritance that could cause corrupted PDF output (invalid PDF data). Credit to @Kagetsuki for opening an issue that let to this discovery.

**Fix**: Fixed an issue with the parser where (ignored) empty strings would cause incorrect alignment when converting PDF dictionary objects from an Array to a Hash, mixing up keys and values. Credit to @Kagetsuki for opening an issue that let to this discovery.

**Fix**: more fixes and refinements to the PDF Names dictionary with better named destination support and document navigation support.

***

#### Change log v.0.2.23

**Fix**: fixed an issue introduced in v.0.2.22, where name dictionary conflict resolution would result in corrupted PDF files. The issue was caused because the name conflict resolution wasn't updated to handle the changes in the new reference linking algorithm used by the parser. During this fix, the whole name dictionary algorithm was re-written, providing better support for named destinations, links and (future feature) ToCs. Credit to Kevin Shen (@kevshin2) for exposing the issue.

***

#### Change log v.0.2.22 (yanked)

**Fix**: fixed an issue with PDF font importing (registering).

**Fix**: fixed issue #65 where some form data (radio buttons) could be lost. Credit to @joshirashmics for exposing the issue.

**Fix**: fixed an issue where empty names would be ignored by the parser (who knew they existed...).

**Fix**: Possible fix for issue #66 (similar to PR #61)... Credit to Serafeim Maroulis (@Reyko) and Kevin Shen (@kevshin2) for exposing the issue.

**Update**: Rewrote some internal algorithms, avoiding recursive logic and optimizing against excessive stack stress.

**Feature**: Credit to Joel Williams (@joelw) for providing `CombinePDF.load` and `CombinePDF.parse` customization, allowing optional content errors to be ignored - taking the risk of a corrupt PDF instead of raising an exception (hey, loading PDF data with optional content sometimes works).

***

#### Change log v.0.2.21

**Fix**: fix for issue #54 and #59 (duplicate), discovered by @iggant (Anton Kolodii), related to name conflict resolution and page resources. The issue would cause and error (exception) to occur when attempting to merge pages with specific resource structures. Credit to @cw6365 (Chris Ward) and @DenKey (Den) as well.

***

#### Change log v.0.2.20

**Fix**: fix for issue #56, discovered by @LeptonHeavy, regarding errors caused by the new PDF form support feature.

***

#### Change log v.0.2.19 (yanked)

**Partial fix**: unconfirmed fix for issue #56, discovered by @LeptonHeavy, regarding errors caused by the new PDF form support feature.

***

#### Change log v.0.2.18 (yanked)

**Feature**: added minor (read: initial and incomplete) PDF forms support, in an attempt to preserve form data when combining PDF files.

***

#### Change log v.0.2.17

**Feature**: added the `page#crop` method to easily crop a PDF file in accordance with the GWG industry association recommendations (updating the `MediaBox` property rather then the `CropBox`). Credit to @wingleungchoi for this feature.

***

#### Change log v.0.2.16

**Fix**: Fix for issue #49 where specific PDF files containing junk data after the %%EOF marker couldn't be opened (as they were invalid files). The issue was fixed by scanning any trailing data before continuing to parse any PDF file beyond the first %%EOF markers (multiple markers are common when using the PDF format). Credit to @wingleungchoi for providing an example for the issue.

***

#### Change log v.0.2.15

**Fix**: Fix for issue #22 where specific PDF files with nested references could cause page stamping to fail, raising an exception. Credit to @tomascharad for finding the issue.

***

#### Change log v.0.2.14

**Fix**: Fix for issue #39, where certain comments could have caused the object after the comments to be ignored, resulting in parsing errors. Credit to @lgn21st for identifying the issue.

***

#### Change log v.0.2.13

**Fix** fixed issue # 37 reported by @sega (thank you for reporting!), regarding the insability to stamp one PDF page over another when one PDF page used a resource directory propegated with data and another page used a resource directory propegated with references. This was now resolved by checking for references before merging the data.

**Compatability**: fixed an issue where PrimoPDF would ommit the required EOL marker before the `endstream`. This would cause malformed PDF files to be written and it is now resolved by allowing the required EOL to be optional.

**Minor**: a minor improvement on the compatability fix related to salvaging PDF data that was misplaced within a PDF comment. This improvement relates to the possibility that there might not be an EOL marker after the `obj` keyword (PaperPort does use an EOL after the `obj` keyword, so this isn't critical).

***

#### Change log v.0.2.12

**Compatability**: fixed issue #36 reported by @vitstradal (thank you for reporting!) regarding PDF files composed by PaperPort. PaperPort (at least version 12) has an issue where PDF data will be placed within a PDF comment. PDF comments start with a "%" sign and end with an EOL marker ("\r" or "\n"). PaperPort ommitted the EOL marker, placing critical data within the comment. A work-around was found by parsing the comment's data and attempting to salvage the misplaced data. This workaround assumes that comments would not contain PDF parsable data at the very end of the comment's line... which is an unsafe assumption. hence, **please let me know if you find _any_ PDF files that worked before the workaround was introduced**.

***

#### Change log v.0.2.11

**Fix**: fix for issue #35 , which was caused by the broken fix for issue #34. Credit to Davek Rupinski for pointing out the issue.

***

#### Change log v.0.2.10

**Fix**: fixed page stamping when the page's content was a referenced object instead or a direct array of content references. Credit to vitstradal for discovering the issue.

***

#### Change log v.0.2.9

**Fix** hopefully fixed issue #33 ([NoMethodError undefined method `[]` for nil:NilClass](https://github.com/boazsegev/combine_pdf/issues/33)).

***

#### Change log v.0.2.8

* **Fix/Feature**: (related to [issue #32](https://github.com/boazsegev/combine_pdf/issues/32))

     Experience shows that it's very difficult to know when to use `page.copy` v.s. `page.copy(true)` before stamping one pdf pages on top (or under) another... So...

     Now there is no longer any need for the guesswork. The process is automated for you.

     The moment CombinePDF recognizes a resource name conflice between two pages (such as both pages using one font name to reference two different fonts), CombinePDF will intrusively rename the incoming page's resources.

     It is true that the intrusive resource renaming is somewhat risky and might require the inflation of some comperssed page data (resulting in bigger file sizes), but this is the only way to attempt and prevent PDF data curruption.

***

#### Change log v.0.2.7

**Fix**: Fixed an issue where a malformed PDF String could cause the parser to hang.

**Update**: Inner PDF links (links to pages within the PDF file) will now be preserved when importing a whole PDF (although Outlines, for now, are discarede and their related links will be discarded as well). If the same destination page is inserted more than once (the first version will be preferred).

**Deprecation Warning**: the `Page_Methods#secure_injection`, `Page_Methods#make_unsecure` and `Page_Methods#make_secure` methods are deprecated. Use `Page_Methods#copy(true)` for safeguarding against font/resource conflicts when "stamping" one PDF page over another.

***

#### Change log v.0.2.6

**fixed**: Hasan Iskandar fixed issue #30 - Output file cannot be saved from Adobe Reader with "Save As optimizes for Fast Web View" preference enabled. Thank you Hasan.

**update**: More parsing error detection; Updated the endstream EOL marker indentifier for safer indentification.

***

#### Change log v.0.2.5

**feature**: circumvents an issue with 'wkhtmltopdf', where sometimes the `endobj` keyword would be missing, causing malformed PDF data. The parser will now attempt to auto-fix any `endobj` missing keywords.

**semi-fix**: make sure decryption is attempetd using actual values (vs. references). The code was updated for a similar result as should have been achived before.

***

#### Change log v.0.2.4

**fixed**: Fixed the default page sizes which weren't as described in the documentation and now default to US Letter. The documentation was also fixed. No major version bump is declered since the defaults were faulty and weren't as described (fixed a bug, not changed the API).

**feature**: added the `resize` page method, to allow resizing of pages with or without conserving the content's aspect ratio (defaults to conserving the aspect ratio).

***

#### Change log v.0.2.3

**update**: a better general error message for CombinePDF.new

**fix**: the `make_secure` now correctly sets the secure copy flag, as expected. For performance reasons it is better to use page.copy(true) for renaming conflicting resource identifiers, but if multiple secure copies are needed for some reason, using `make_secure` will now make sure each copy is secured independently.

**fix**: the secure copy now worked as expected (it had issue with referenced resource dictionaries that was resolved by following the references).

**fix**: fixed an object numbering issue introduced by duplicating pages as part of the Adobe Reader bug workaround. The issue was thought to have been fixed before but some PDF structures were not proprly addressed.

***

#### Change log v.0.2.2

**fix**: fixed the default value for the :location attribute of PDF#stamp_pages(String, options). Now, instead of the default stamp being written at [:top, :bottom], it's default location will be set to [:center].

**fix**: fixed the 'center' location in the page numbering, so that it wouldn't enforce a small font on an all page centered number.

***

#### Change log v.0.2.1

**fix**: better page stamping... or, at least more secure (we hope).

**feature**: added the PDF#stamp_pages shortcut method. Credit to Tania (@taniarv) for the concept.

**fix**: possible string encoding issues could have arose when strings were rendered to PDF format. Credit to Tania (@taniarv) for exposing the issue.

**feature**: Metadata is now easier to set by allowing fast access to the Information header when using PDF#save and PDF#to_pdf. Credit to Tania (@taniarv) for code.

***

#### Change log v.0.2.0

Refractoring of code and API overhall.

Any code relying on inner/advanced API calls might be broken.

**fix**: fixed an object numbering issue introduced by duplicating pages. The issue didn't seem to effect readers nor performance.

**fix**: combine_pdf will now properly raise an error when Optional Content Groups (OCG's) are implemented in a PDF file. Page extraction isn't supported for PDF files with OCG's.

***

#### Change log v.0.1.23

**fix**: @kruszczynski fixed an issue with CombinePDF::PDF#number_pages where the page numbering margines were ignored and only the default values were used. Thank you @kruszczynski .

***

#### Change log v.0.1.22

**fix**: a tested fix for issue #19, where Acrobat Reader would raise an error if page objects in the Catalog were copied by reference instead of copied in full and each was assigned different a unique object id. (possibly an Acrobat Reader Issue workaround) The issue was resolved by exempting page objects from the duplication reduction algorithm, and in this way, forcing duplicates to be copied rather then referenced in the Catalog object.

***

#### Change log v.0.1.21

**fix**: an attempted fix for issue #19, where the xref table wasn't read on Acrobat Reader, probably due to a double EOL marker at the end of each entry.

***

#### Change log v.0.1.20

**fix**: due to some PDF files not conforming to the required EOL marker in the endstream object specifications, the parser is now back to a non-strict parsing mode for PDF Stream Objects. Conforming files weren't found to be effected and although it is unlikely, it is possible that they might be effected if the stream object would contain the 'endstream' keyword without the required EOL marker and without intending to end the stream object.

***

#### Change log v.0.1.19

**fix**: merged @espinosa's fix for issue #16 which affected windows machines.

**feature**: added a #write_table method to the PDF pages, allowing tables to be written on existing PDF pages. This is a destructive method (it changes the table_data array by removing any rows written to the page and leaving the rest of the data untouched, for future writing). Read the documentation before using this method.

**update**: stricter parsing for PDF Stream Objects is now enforced. The stricter parsing is NOT final, as it walks a fine line between allowing non-conforming PDF files to be read and risking an error while reading a correctly structured file which has PDF keywords intentionaly embedded in a correctly structured object stream (keywords which would be normally ignored as expected, but which will be recognized as relevant if the parser is less strict about the structure of the PDF file).

***

#### Change log v.0.1.18

**fix**: Thank to Stefan, who reported issue #15 , we discovered that in some cases PDF files presented the wrong PDF standard version, causing an error while attempting to parse their data. The issue has been fixed by allowing the parser to search for PDF Object Streams even when the PDF file claims a PDF version below 1.5.

***

#### Change log v.0.1.17

**feature**: Although it was possible to create and add empty PDF pages (at any location), it is now even easier with one method call to add empty pages at the end of a PDF object. It's also possible to add text to these empty pages or stamp them with different content.

**fix?**: a possible multi-threading issue might have existed where to threads saving PDF data at the same time might corrupt PDF data (although this theoretical issue was never reported and probably never encountered). The PDF streams should now be a bit more thread safe, as long as no two threads attempt to render the same PDF object at the same time.

**fix**: Thank to Georg, who reported issue #14 , we are now working on a fix of a mysterious issue with textboxes which could effect page numbering and textboxes on certain PDF files. It is unknown at this time if the issue is resolved and the fix is awaiting confirmation. The issue effected only some PDF files and not others.

***

#### Change log v.0.1.16

**fix?**: Compatability reports came in showing that some email servers convery new-line (\n) characters to CRLF (\r\n) - corrupting the binary code in the PDF files. This version attemps to fix this by adding more binary characters to the first comment line of the PDF file (right after the header). Most email programs and Antivirus programs should preserve the original EOL character once they recognize the file as binary.

***

#### Change log v.0.1.15

**features**: added new PDF#Page API to deal with page rotation and orientation. see the docs for more info.

***

#### Change log v.0.1.14

**changes**: changed the way the PDF Page objects are 'injected' with their methods, so that the PDF#pages method is faster and more methods can be injected into the Hash object. For instance, textbox can now be called on an existing page without creating a PDFWriter object and 'stumping' the new data.

(the number_pages method hasn't been update to use this new feature as of yet)

***

#### Change log v.0.1.13

**fix**: fix for Acrobat Reader compatablity (by removing color-space declarations). Should solve issue #13 , reported originaly by Imanol and Diyei Gomi.

***

#### Change log v.0.1.12

**fix**: fix for page rotation inheritance.

**fix**: fix for the issue was discovered while observing issue #13, reported originaly by Imanol and Diyei Gomi. The issue was probably caused by parsing errors introduced while parsing hex strings (a case sensitive method was used by mistake and this is now corrected).
***

#### Change log v.0.1.11

**fix**: fixed a bug where Page Resources and ColorSpace data wouldn't be inherited correctly from the Catalog and Pages parent objects. This issue could cause pages to render without all their content intact. This issue is now fixed (although more testing should be done for multiple inheritance).

**?fix?** Attempted to fix [the issue reported by srogers](https://github.com/boazsegev/combine_pdf/issues/10), by forcing all String byte collections to return an Array. waiting confirmation for fix (couldn't reproduce the issue just yet, as I can't seem to install Ruby MRI 1.9.3 on my mac).

***

#### Change log v.0.1.10

**fix**: fixed a typo that prevented access to the CombinePDF::VERSION constant.

***

#### Change log v.0.1.9

**fix**: possible fix for bug reported by lamphuongha, regarding PDF 1.5 streams. I await confirmation that the fix actually works, as I cannot seem to reproduce the whole spectrum of the bug on my system...

***

#### Change log v.0.1.8

**fix**: Fixed an [issue reported by Saba](https://github.com/boazsegev/combine_pdf/issues/8), where PDF files that were written using bad practices (namely, without wrapping their content streams correctly) would not be stamped correctly due to changes in the space matrix (CTM). Fixed by wrapping all existing streams before stamping.

***

#### Change log v.0.1.7

**fix**: PDF `insert` had a typo in the code that would cause failure when unsupported object insertion was attempted - fixed by Nathan Keyes (nkeyes).

***

#### Change log v.0.1.6

**fix**: added Mutex to font library (which was shared by all PDFWriter objects) - now fonts are thread safe (PDF objects are NOT thread safe by design).

**fix**: RTL recognition did not reverse brackets, it should now correctly perform brackets reversal for any of the following: (,),[,],{,},<,>.

**update**: updated license to MIT.

**known issues**: encrypted PDF files can sometimes silently fail (producing empty pages) - this is because on an attempted decrypt. more work should be done to support encrypted PDF files. please feel fee to help.

I use this version on production, where I have control over the PDF files I use. It is beter then system calls to pdftk (which can cause all threads in ruby to hold, effectively causing my web app to hang).
