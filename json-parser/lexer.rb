require "minitest/autorun"

class Lexer
  class TokenizationError < StandardError; end

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
  # let's not support single quote strings initially
  # SINGLE_QUOTE = "'"

  NULL = "null"
  TRUE = "true"
  FALSE = "false"

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

  def initialize(input)
    @input = input
    @position =  nil
    @char = nil
    @tokens = []
  end

  attr_reader :input, :position, :char, :tokens

  def tokenize
    while (token = next_token)
      tokens << token
    end

    tokens
  end

  def next_token
    consume_char

    return if char.nil?
    return char if SYMBOLS.include? char

    if char == DOUBLE_QUOTE
      consume_string_literal_token
    else
      consume_value_token
    end
  end

  def consume_value_token
    # TODO.

    # a non-symbol first char means
    # the token may be N chars long.
    # this isn't handle strings so that leaves us with:
    # 1, 123, 3.14, true, false
  end

  def consume_string_literal_token
    initial_position = position

    token = char # opening "
    until consume_char == "\"" || (position > input.length - 1)
      token << char
    end

    if position > input.length - 1
      # TODO: it would be fun to print a preview of the location:
      #  "id : 123 }
      #  ^
      raise TokenizationError, "Tokenization failed: unterminated string literal at position #{initial_position}"
    end

    token << char # closing "

    return token
  end

  def consume_char
    if position.nil?
      @position = 0
      @char = input[position]
    else
      @position += 1
      @char = input[position]
    end

    eat_whitespace

    @char
  end

  def eat_whitespace
    while WHITESPACE_CHARACTERS.include?(char)
      @position += 1
      @char = input[position]
    end
  end

  def peek_char
    input[position+1]
  end
end

class LexerTest < Minitest::Test
  def test_lexer
    input = <<~JSON
       {
        "id": 123
      }
    JSON

    lexer = Lexer.new(input)
    lexer.tokenize

    assert_equal(lexer.tokens, [
      "{", "\"id\"", ":", "123", "}"
    ])
  end
end
