require "minitest/autorun"

class Lexer
  def initialize(reader)
    @buffer = ""
    @reader = reader # probably a StringIO?
  end

  def next_token
  end

  attr_reader :buffer, :reader
end

class LexerTest < Minitest::Test
end
