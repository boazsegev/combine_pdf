require 'bundler/setup'
require 'minitest/autorun'
require 'combine_pdf'

describe CombinePDF::PDFDecrypt do
  def v4_encryption_dictionary
    {
      Filter: :Standard,
      V: 4,
      R: 4,
      Length: 128,
      CF: { StdCF: { CFM: :AESV2, Length: 16 } },
      StmF: :StdCF,
      StrF: :StdCF,
      O: ("\x00".b * 32),
      U: ("\x00".b * 32),
      P: -4
    }
  end

  it 'treats a missing V4 crypt filter AuthEvent as DocOpen' do
    root = {
      Encrypt: v4_encryption_dictionary,
      ID: ["\x00".b * 16]
    }

    assert_equal [], CombinePDF::PDFDecrypt.new([], root).decrypt
  end
end
