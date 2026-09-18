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

  describe 'with page resources that reference themselves' do
    # e.g. LibreOffice transparency groups: Resources -> XObject -> Resources,
    # shared by the Pages node and the Page (see issue #242)
    let(:file) { 'self_referencing_resources.pdf' }

    it('parses without a SystemStackError') do
      assert_instance_of CombinePDF::PDF, subject
      assert_equal 1, subject.pages.count
    end

    it('can be merged and rendered') do
      pdf = CombinePDF.new
      pdf << subject
      pdf << CombinePDF.load('test/fixtures/files/sample_pdf.pdf')
      assert_equal 2, CombinePDF.parse(pdf.to_pdf).pages.count
    end
  end
end
