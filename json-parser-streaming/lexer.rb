require "minitest/autorun"

class Token
  def initialize(type:, value:)
    @type = type
    @value = value
  end

  attr_reader :type, :value

  def to_a
    [type, value]
  end

  def to_s
    @value
  end
end

class Lexer
  class Wat < StandardError; end

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

  # Token types
  LBRACE = "{"
  RBRACE = "}"
  LBRACKET = "["
  RBRACKET = "]"
  COLON = ":"
  COMMA = ","

  SYMBOLS = [
    LBRACE,
    RBRACE,
    LBRACKET,
    RBRACKET,
    COLON,
    COMMA
  ]

  DOUBLE_QUOTE = "\""

  def initialize(source)
    @buffer = []
    @source = source
  end

  attr_reader :buffer, :source

  # TODO: expose an enumerable method such as #each_token

  def next_token
    eat_whitespace

    char = peek
    return if char.nil?

    return Token.new(type: :SYMBOL, value: char) if SYMBOLS.include? char

    if char == DOUBLE_QUOTE
      consume_string_literal_token
    else
      # consume_value_token
    end
  end

  def consume_string_literal_token
    if getc != DOUBLE_QUOTE
      raise Wat, "\#consume_string_literal_token called, but the next char is not an opening quotation mark"
    end

    value = "" << DOUBLE_QUOTE

    until (char = getc) == DOUBLE_QUOTE
      raise Wat, "unclosed string literal '#{value}'" if char.nil?
      value << char
    end

    value << DOUBLE_QUOTE

    return Token.new(type: :STRING, value:)
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

  def test_symbol_token
    source = StringIO.new("{")
    lexer = Lexer.new(source)

    assert_equal([:SYMBOL, "{"], lexer.next_token.to_a)
  end

  def test_string_literal_token
    source = StringIO.new("\"hello\"")
    lexer = Lexer.new(source)

    assert_equal([:STRING, "\"hello\""], lexer.next_token.to_a)
  end

  def test_string_literal_token_with_escaped_double_quote
    source = StringIO.new('"\"hello\""')
    lexer = Lexer.new(source)

    assert_equal([:STRING, '"\"hello\""'], lexer.next_token.to_a)
  end
end
