require 'bundler/setup'
require 'minitest/autorun'
require 'combine_pdf'
# decrypt.rb uses OpenSSL::Cipher without requiring it and returns the stream
# still encrypted when the constant is missing.
require 'openssl'
require 'zlib'

# AES-128 (V 4 / R 4) with an empty user password and EncryptMetadata false.
# Building the file key appends 0xFFFFFFFF for such files; that literal is
# frozen in decrypt.rb and must not be mutated.
describe 'CombinePDF.load with EncryptMetadata false' do
  FIXTURE = 'test/fixtures/files/sample_aes_unencrypted_metadata_pdf.pdf'.freeze

  def content_of(page)
    contents = page[:Contents]
    contents = contents.first if contents.is_a?(Array)
    # the content stream is FlateDecode compressed; AES padding follows the deflate data.
    Zlib::Inflate.new.inflate((contents[:referenced_object] || contents)[:raw_stream_content])
  end

  it 'decrypts the file instead of raising EncryptionError' do
    pdf = CombinePDF.load(FIXTURE)

    assert_equal 1, pdf.pages.count
    assert_includes content_of(pdf.pages.first), 'Readable customer scan'
  end

  it 'keeps the page when merged after an unencrypted file' do
    merged = CombinePDF.new
    merged << CombinePDF.load('test/fixtures/files/sample_pdf.pdf')
    plain_pages = merged.pages.count
    merged << CombinePDF.load(FIXTURE)

    reloaded = CombinePDF.parse(merged.to_pdf)

    assert_equal plain_pages + 1, reloaded.pages.count
    assert_includes content_of(reloaded.pages.last), 'Readable customer scan'
  end
end
