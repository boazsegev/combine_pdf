require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/around/spec'
require 'combine_pdf'

describe 'CombinePDF.load' do
  let(:options) { {} }

  subject { CombinePDF.load "test/fixtures/files/#{file}", options }

  describe 'raise_on_encrypted option' do
    let(:file) { 'sample_encrypted_pdf.pdf' }
    let(:options) { { raise_on_encrypted: raise_on_encrypted } }

    describe 'when raise_on_encrypted: true' do
      let(:raise_on_encrypted) { true }

      describe 'with encrypted file' do
        it('raises an CombinePDF::EncryptionError') do
          error = assert_raises(CombinePDF::EncryptionError) { subject }
          assert_match 'the file is encrypted', error.message
        end
      end

      describe 'with unencrypted file' do
        let(:file) { 'sample_pdf.pdf' }

        it('has a PDF') { assert_instance_of CombinePDF::PDF, subject }
      end
    end

    describe 'when raise_on_encrypted: false' do
      let(:raise_on_encrypted) { false }

      describe 'with encrypted file' do
        it('does not raise an CombinePDF::EncryptionError') do
          assert_instance_of CombinePDF::PDF, subject
        end
      end

      describe 'with unencrypted file' do
        let(:file) { 'sample_pdf.pdf' }

        it('has a PDF') { assert_instance_of CombinePDF::PDF, subject }
      end
    end
  end
end
