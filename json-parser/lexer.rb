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

  TERMINAL_CHARACTERS = SYMBOLS + WHITESPACE_CHARACTERS

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
    token = char

    until TERMINAL_CHARACTERS.include?(peek_char)
      consume_char
      token << char
    end

    token
  end

  def consume_string_literal_token
    opening_position = position

    token = char # opening "
    until consume_char == "\""
      unclosed_string_literal_error!(opening_position) if char.nil?
      token << char
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

  def unclosed_string_literal_error!(opening_position)
    error_line = nil
    error_line_opening_position = nil
    chars_seen = 0

    input.each_line do |line|
      next_chars_seen = chars_seen + line.length
      if next_chars_seen >= opening_position
        error_line = line
        error_line_opening_position = opening_position - chars_seen
        break
      end

      chars_seen = next_chars_seen
    end

    # TODO: use a sliding window to create a fixed size preview, in case the line is very long
    preview = error_line

    message = "Tokenization failed: unclosed string literal at position #{opening_position}:" \
      "\n\t#{preview}" \
      "\n\t\e[31m#{' '*error_line_opening_position}^\e[0m"

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
        }
      }
    JSON

    lexer = Lexer.new(input)
    lexer.tokenize

    assert_equal([
      "{",
       "\"id\"", ":", "123", ",",
       "\"details\"", ":", "{",
       "\"name\"", ":", "\"jacob\"", ",",
       "\"hobbies\"", ":", "[", "\"programming\"", ",", "\"pickleball\"", "]",
       "}",
       "}"
    ], lexer.tokens)
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
end
