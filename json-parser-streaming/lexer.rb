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

  JSON_NUMERIC = /\A-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?\z/

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

  NULL = "null"
  TRUE = "true"
  FALSE = "false"

  TERMINAL_CHARACTERS = SYMBOLS + WHITESPACE_CHARACTERS

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

    return Token.new(type: :SYMBOL, value: getc) if SYMBOLS.include? char

    if char == DOUBLE_QUOTE
      consume_string_literal_token
    else
      consume_value_token
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

  def consume_value_token
    value = ""
    until TERMINAL_CHARACTERS.include?(peek) || peek.nil?
      c = getc
      value << c
    end

    if [TRUE, FALSE].include?(value)
      return Token.new(type: :BOOL, value:)
    elsif value == NULL
      return Token.new(type: :NULL, value:)
    else
      int, float = value.match(JSON_NUMERIC).deconstruct
      if float
        return Token.new(type: :FLOAT, value:)
      elsif int
        return Token.new(type: :INTEGER, value:)
      else
        raise Wat, "Unhandled token type for value: #{value}"
      end
    end
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

  # def test_string_literal_token_with_escaped_double_quote
  #   source = StringIO.new('"\"hello\""')
  #   lexer = Lexer.new(source)

  #   assert_equal([:STRING, '"\"hello\""'], lexer.next_token.to_a)
  # end

  def test_bool_token
    source = StringIO.new("true")
    lexer = Lexer.new(source)

    assert_equal([:BOOL, "true"], lexer.next_token.to_a)
  end

  def test_null_token
    source = StringIO.new("null")
    lexer = Lexer.new(source)

    assert_equal([:NULL, "null"], lexer.next_token.to_a)
  end

  def test_int_token
    source = StringIO.new("42")
    lexer = Lexer.new(source)

    assert_equal([:INTEGER, "42"], lexer.next_token.to_a)
  end

  def test_int_token
    source = StringIO.new("3.14")
    lexer = Lexer.new(source)

    assert_equal([:FLOAT, "3.14"], lexer.next_token.to_a)
  end

  def test_lexer_basic
    source = StringIO.new(<<~JSON
       {
        "id": 123,
        "details": {
          "name": "jacob",
          "hobbies": ["programming", "pickleball"]
        },
        "health": 6.5,
        "weight_in_grams": 6.8e4
      }
    JSON
    )

    lexer = Lexer.new(source)

    tokens = []
    until (token = lexer.next_token) == nil
      tokens << token
    end

    assert_equal([
      [:SYMBOL, "{"],
      [:STRING, "\"id\""], [:SYMBOL, ":"], [:INTEGER, "123"], [:SYMBOL, ","],
      [:STRING, "\"details\""], [:SYMBOL, ":"], [:SYMBOL, "{"],
      [:STRING, "\"name\""], [:SYMBOL, ":"], [:STRING, "\"jacob\""], [:SYMBOL, ","],
      [:STRING, "\"hobbies\""], [:SYMBOL, ":"], [:SYMBOL, "["], [:STRING, "\"programming\""], [:SYMBOL, ","], [:STRING, "\"pickleball\""], [:SYMBOL, "]"],
      [:SYMBOL, "}"], [:SYMBOL, ","],
      [:STRING, "\"health\""], [:SYMBOL, ":"], [:FLOAT, "6.5"], [:SYMBOL, ","],
      [:STRING, "\"weight_in_grams\""], [:SYMBOL, ":"], [:FLOAT, "6.8e4"],
      [:SYMBOL, "}"]
    ],
      tokens.map(&:to_a)
    )
  end
end
