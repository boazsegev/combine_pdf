require 'bundler/setup'
require 'minitest/autorun'
require 'combine_pdf'

class CombinePDFRC4Test < Minitest::Test
  VECTORS = {
    'Key' => ['Plaintext', 'BBF316E8D940AF0AD3'],
    'Wiki' => ['pedia', '1021BF0420'],
    'Secret' => ['Attack at dawn', '45A01F645FC35B383552544B9BF5']
  }.freeze

  def test_decrypts_known_vectors
    VECTORS.each do |key, (plaintext, ciphertext)|
      assert_equal plaintext.b, CombinePDF::RC4.new(key).decrypt([ciphertext].pack('H*'))
    end
  end

  def test_decrypt_does_not_modify_its_input
    ciphertext = ['BBF316E8D940AF0AD3'].pack('H*')
    original = ciphertext.dup
    CombinePDF::RC4.new('Key').decrypt(ciphertext)

    assert_equal original, ciphertext
  end
end
