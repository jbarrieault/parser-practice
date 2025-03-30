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
  class TokenizationError < StandardError; end

  JSON_NUMERIC = /\A-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?\z/

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

  TERMINAL_CHARACTERS = SYMBOLS + WHITESPACE_CHARACTERS

  def initialize(input)
    @input = input
    @position = nil
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
    return Token.new(type: :SYMBOL, value: char) if SYMBOLS.include? char

    if char == DOUBLE_QUOTE
      consume_string_literal_token
    else
      consume_value_token
    end
  end

  def consume_value_token
    value = char

    until TERMINAL_CHARACTERS.include?(peek_char)
      consume_char
      value << char
    end

    int, float = value.match(JSON_NUMERIC).deconstruct
    if float
      return Token.new(type: :FLOAT, value:)
    elsif int
      return Token.new(type: :INTEGER, value:)
    elsif [TRUE, FALSE].include?(value)
      return Token.new(type: :BOOL, value:)
    elsif value == NULL
      return Token.new(type: :NULL, value:)
    else
      raise "Unhandled token type for value: #{value}"
    end
  end

  def consume_string_literal_token
    opening_position = position

    value = char # opening "
    until consume_char == "\""
      unclosed_string_literal_error!(opening_position) if char.nil?
      value << char
    end

    value << char # closing "

    return Token.new(type: :STRING, value:)
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

  def unclosed_string_literal_error!(opening_position)
    error_line = nil
    chars_seen = 0

    input.each_line do |line|
      next_chars_seen = chars_seen + line.length
      if next_chars_seen >= opening_position
        error_line = line.chomp
        break
      end

      chars_seen = next_chars_seen
    end

    preview_i = [opening_position-10, 0].max
    preview_j = [opening_position+25, error_line.length-1].min
    preview = error_line[preview_i..preview_j]

    preview_error_position = opening_position - preview_i

    # require 'pry'
    # binding.pry
    message = "Tokenization failed: unclosed string literal at position #{opening_position}:" \
      "\n\t#{preview}" \
      "\n\t\e[31m#{' '*preview_error_position}^\e[0m"

    raise TokenizationError, message
  end
end

class LexerTest < Minitest::Test
  def test_lexer_basic
    input = <<~JSON
       {
        "id": 123,
        "details": {
          "name": "jacob",
          "hobbies": ["programming", "pickleball"]
        },
        "health": 6.5
      }
    JSON

    lexer = Lexer.new(input)
    lexer.tokenize

    assert_equal([
      [:SYMBOL, "{"],
      [:STRING, "\"id\""], [:SYMBOL, ":"], [:INTEGER, "123"], [:SYMBOL, ","],
      [:STRING, "\"details\""], [:SYMBOL, ":"], [:SYMBOL, "{"],
      [:STRING, "\"name\""], [:SYMBOL, ":"], [:STRING, "\"jacob\""], [:SYMBOL, ","],
      [:STRING, "\"hobbies\""], [:SYMBOL, ":"], [:SYMBOL, "["], [:STRING, "\"programming\""], [:SYMBOL, ","], [:STRING, "\"pickleball\""], [:SYMBOL, "]"],
      [:SYMBOL, "}"], [:SYMBOL, ","],
      [:STRING, "\"health\""], [:SYMBOL, ":"], [:FLOAT, "6.5"],
      [:SYMBOL, "}"]
    ],
      lexer.tokens.map(&:to_a)
    )
  end

  def test_lexer_top_level_array
    input = <<~JSON
      [1, "b", 3.14]
    JSON

    lexer = Lexer.new(input)
    lexer.tokenize

    assert_equal([
      [:SYMBOL, "["], [:INTEGER, "1"], [:SYMBOL, ","], [:STRING, "\"b\""], [:SYMBOL, ","], [:FLOAT, "3.14"], [:SYMBOL, "]"]
    ],lexer.tokens.map(&:to_a))
  end

  def test_lexer_unterminated_string_literal
    input = <<~JSON
       {
        "id": 123,
        "age: 34
      }
    JSON

    lexer = Lexer.new(input)

    err = assert_raises(Lexer::TokenizationError) do
      lexer.tokenize
    end

    assert_match /Tokenization failed: unclosed string literal at position 18/, err.message
  end

  def test_lexer_unterminated_string_literal
    input = <<~JSON
       { "very_long_property_name_string_for_testing_unclosed_string_error_message_preview": "this string is never closed }
    JSON

    lexer = Lexer.new(input)

    err = assert_raises(Lexer::TokenizationError) do
      lexer.tokenize
    end

    expected_message = <<~MSG.chomp
      Tokenization failed: unclosed string literal at position 86:
      \tpreview": "this string is never clos
      \t          ^
    MSG

    # remove the ANSI escape sequence coloring in the actual error message
    uncolorized_err_message = err.message.gsub(/\e\[[0-9;]*m/, '')

    assert_match(expected_message,uncolorized_err_message)
  end
end
