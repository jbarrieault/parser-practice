require "minitest/autorun"

class Lexer
  LBRACE = "{"
  RBRACE = "}"
  COLON = ":"
  COMMA = ","

  SYMBOLS = [
    LBRACE,
    RBRACE,
    COLON,
    COMMA
  ]

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

    # TODO: parse multi-char tokens
    char
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
    # invalid, but just for now
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
