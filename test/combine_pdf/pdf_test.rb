require 'bundler/setup'
require 'minitest/autorun'
require 'combine_pdf'

describe CombinePDF::PDF do
  subject { CombinePDF.load("test/fixtures/files/#{file}") }

  describe 'AcroForm documents' do
    let(:file) { 'acro_form.pdf' }

    it('knows that it is an acro form') { assert(subject.form? == true) }
    it('knows that it is NOT a dynamic XFA form') { assert(subject.xfa_form? == false) }
  end

  describe 'dynamic xfa documents' do
    let(:file) { 'xfa_form.pdf' }

    it('knows that it is an acro form') { assert(subject.form? == true) }
    it('knows that it is IS a dynamic XFA form') { assert(subject.xfa_form? == true) }
  end
end
