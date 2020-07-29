require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/around/spec'
require 'combine_pdf'

describe 'CombinePDF.load' do
  let(:options) { {} }

  subject { CombinePDF.load "test/fixtures/files/#{file}", options }

  describe 'raise_on_encrypted option' do
    let(:raise_on_encrypted) { false }
    let(:file) { 'sample_encrypted_pdf.pdf' }
    let(:options) { { raise_on_encrypted: raise_on_encrypted } }

    it('has a PDF') { assert_instance_of CombinePDF::PDF, subject }

    describe 'raise_on_encrypted: true' do
      let(:raise_on_encrypted) { true }

      it('raises an CombinePDF::EncryptionError') do
        assert_raises(CombinePDF::EncryptionError) { subject }
      end

      describe 'non-encrypted files' do
        let(:file) { 'sample_pdf.pdf' }

        it('has a PDF') { assert_instance_of CombinePDF::PDF, subject }
      end

      describe 'Zlib::DataError' do
        let(:encrypted?) { false }
        let(:parser) { Minitest::Mock.new }

        around do |example|
          parser.expect(:parse, true) { raise Zlib::DataError, 'incorrect data header' }
          root_object = encrypted? ? { Encrypt: :yes } : { NotEncrypted: :cool }
          parser.expect(:root_object, root_object)
          parser.expect(:raise_on_encrypted, raise_on_encrypted)
          parser.expect(:is_a?, true, [CombinePDF::PDFParser])
          CombinePDF::PDFParser.stub(:new, parser) { |_| example.call }
        end

        it('raises Zlib::DataError') do
          assert_raises(Zlib::DataError) { subject }
        end

        describe 'encrypted' do
          let(:encrypted?) { true }

          it('raises an CombinePDF::EncryptionError') do
            assert_raises(CombinePDF::EncryptionError) { subject }
          end
        end
      end
    end
  end
end
