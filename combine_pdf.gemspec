# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'combine_pdf/version'

Gem::Specification.new do |spec|
  spec.name          = "combine_pdf"
  spec.version       = CombinePDF::VERSION
  spec.authors       = ["Boaz Segev"]
  spec.email         = ["boaz@2be.co.il"]
  spec.summary       = %q{Combine, stamp and watermark PDF files in pure Ruby.}
  spec.description   = %q{A nifty gem, in pure Ruby, to parse PDF files and combine (merge) them with other PDF files, number the pages, watermark them or stamp them, create tables, add basic text objects etc` (all using the PDF file format).}
  spec.homepage      = "https://github.com/boazsegev/combine_pdf"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'ruby-rc4', '>= 0.1.5'

  # spec.add_development_dependency "bundler", ">= 1.7"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest"
end
