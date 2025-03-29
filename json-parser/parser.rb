require "minitest/autorun"

class Parser
  class ParseError < StandardError; end

  def initialize(tokens:)
    @tokens = tokens
    @position = 0
    @current_token = tokens[@position]
    @result
  end

  attr_reader :tokens, :position, :current_token

  def parse
    until consume.nil?
      case current_token.value
      when Lexer::LBRACE
        parse_object
      when Lexer::LBRACKET
        parse_array
      else
        parse_value
      end
    end
  end

  def parse_object
    expect(Lexer::LBRACE)

    # TODO: parse inner property/value pairs, then expect RBRACE
  end

  def parse_array
    expect(Lexer::LBRACKET)

    # TODO: parse inner values, then expect RBRACKET
  end

  def parse_value
    # TODO: convert current_token.value into corresponding Ruby object
  end

  def consume
    @position += 1
    @current_token = tokens[position]
  end

  def peek
    tokens[position+1]
  end

  def expect(value)
    if current_token.value != value
      consume
    else
      raise ParseError, "Expected token value #{value} at position #{position}, got: #{current_token.value}"
    end
  end
end

class ParserTest < Minitest::Test
  def test_parser
    assert_equal(true, true)
  end
end
