$LOAD_PATH.unshift File.expand_path(File.join('..', '..', 'lib'), __FILE__ )
require 'minitest/spec'
require 'minitest/autorun'
require 'fileutils'
require "combine_pdf"

class CombinePDFTest 
  describe 'Combine pdfs' do
    before(:all) do
      FileUtils.mkdir_p("./test/tmp")
    end
    
    after(:all) do
      FileUtils.rm_r('./test/tmp/')
    end
    
    describe 'with unecrypted pdfs' do
      before do
        @paths = %w(./test/fixtures/pdf_one.pdf ./test/fixtures/pdf_two.pdf)
      end
      
      it 'does combine the pdfs into a single file' do
        combined_pdf = CombinePDF.new
        @paths.each { |p| combined_pdf << CombinePDF.load(p) }
        combined_pdf.save("./test/tmp/combined.pdf")
        assert(File.exists?('./test/tmp/combined.pdf'))
      end
    end
    
    describe 'with encrypted pdfs' do
      before do
        @paths = %w(./test/fixtures/pdf_one.pdf ./test/fixtures/encrypted.pdf)
      end
      
      it 'does combine the pdfs into a single file' do
        combined_pdf = CombinePDF.new
        @paths.each { |p| combined_pdf << CombinePDF.load(p) }
        combined_pdf.save("./test/tmp/combined.pdf")
        assert(File.exists?('./test/tmp/combined.pdf'))
      end
    end
  end
end
