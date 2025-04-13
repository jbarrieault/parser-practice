require "minitest/autorun"

class Lexer
  SPACE = " "
  NEWLINE = "\n"
  CARRIAGE_RETURN = "\r"
  TAB = "\t"

  WHITESPACE_CHARACTERS = [
    SPACE,
    NEWLINE,
    CARRIAGE_RETURN,
    TAB
  ]

  def initialize(source)
    @buffer = []
    @source = source
  end

  attr_reader :buffer, :source

  def next_token
    eat_whitespace
  end

  def eat_whitespace
    while WHITESPACE_CHARACTERS.include?(peek)
      getc
    end
  end

  def getc
    return @buffer.shift unless @buffer.empty?

    source.getc
  end

  def peek
    @buffer << source.getc if @buffer.empty?
    @buffer[0]
  end
end

class LexerTest < Minitest::Test
  def test_eat_whitespace
    source = StringIO.new("     a")
    lexer = Lexer.new(source)
    lexer.send(:eat_whitespace)

    assert_equal("a", lexer.getc)
  end
end
