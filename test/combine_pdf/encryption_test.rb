require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/around/spec'
require 'combine_pdf'

describe 'CombinePDF.encrypted?' do
  subject { CombinePDF.encrypted? file }

  describe 'encrypted files' do
    let(:file) { 'test/fixtures/files/sample_encrypted_pdf.pdf' }

    it('knows they are encrypted') { assert subject == true }

    describe Zlib::DataError do
      let(:parser) { Minitest::Mock.new }

      around do |example|
        parser.expect(:parse, true) { raise Zlib::DataError, 'incorrect data header' }
        parser.expect(:root_object, Encrypt: { stuff: :yes })
        CombinePDF::PDFParser.stub(:new, parser) { |_| example.call }
      end

      it { assert subject == true }
    end
  end

  describe 'non-encrypted files' do
    let(:file) { 'test/fixtures/files/sample_pdf.pdf' }

    it('knows they are NOT encrypted') { assert subject == false }

    describe Zlib::DataError do
      let(:parser) { Minitest::Mock.new }

      around do |example|
        parser.expect(:parse, true) { raise Zlib::DataError, 'incorrect data header' }
        parser.expect(:root_object, NotEncrypted: {})
        CombinePDF::PDFParser.stub(:new, parser) { |_| example.call }
      end

      it { assert subject == false }
    end
  end
end
