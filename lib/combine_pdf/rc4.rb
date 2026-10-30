# -*- encoding : utf-8 -*-
# frozen_string_literal: true
########################################################
## Adapted from the ruby-rc4 gem (https://github.com/caiges/Ruby-RC4)
## and subject to its license:
##
## The MIT License
##
## Copyright (C) 2010 Max Prokopiev, Alexandar Simic, Caige Nichols
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
## THE SOFTWARE.
########################################################

module CombinePDF
  # @private
  # @!visibility private

  # This is an internal class. you don't need it.
  class RC4
    def initialize(key)
      key_bytes = key.bytes
      @q1 = 0
      @q2 = 0
      @s = (0..255).to_a
      j = 0
      256.times do |i|
        j = (j + @s[i] + key_bytes[i % key_bytes.length]) % 256
        @s[i], @s[j] = @s[j], @s[i]
      end
    end

    def decrypt(text)
      text.unpack('C*').map { |c| c ^ round }.pack('C*')
    end

    private

    def round
      @q1 = (@q1 + 1) % 256
      @q2 = (@q2 + @s[@q1]) % 256
      @s[@q1], @s[@q2] = @s[@q2], @s[@q1]
      @s[(@s[@q1] + @s[@q2]) % 256]
    end
  end
end
