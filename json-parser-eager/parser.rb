require "minitest/autorun"
require_relative "lexer"

class Parser
  class ParseError < StandardError; end

  def initialize(tokens:)
    @tokens = tokens
    @position = 0
    @current_token = tokens[@position]
  end

  attr_reader :tokens, :position, :current_token

  def parse
    until advance.nil?
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
    case current_token.type
    when :INTEGER
      current_token.value.to_i
    when :FLOAT
      current_token.value.to_f
    when :STRING
      parse_string
    when :NULL
      nil
    when :BOOL
      parse_bool
    end
  end

  def parse_string
    # the lexer preserves the surrounding quotes, but we need to get rid of them
    unless current_token.length >= 2 && current_token.starts_with?('"') && current_token.ends_with?('"')
      raise ParseError, "Encountered STRING token with invalid value: #{current_token.value.inspect}"
    end

    current_token[1..-2]
  end

  def parse_bool
    if current_token.value == "true"
      true
    elsif current_token.value == "false"
      false
    else
      raise ParseError, "Encountered BOOL token with invalid value: #{current_token.value}"
    end
  end

  def advance
    @position += 1
    @current_token = tokens[position]
  end

  def peek
    tokens[position+1]
  end

  def expect(value)
    if current_token.value != value
      advance
    else
      raise ParseError, "Expected token value #{value} at position #{position}, got: #{current_token.value}"
    end
  end
end

class ParserTest < Minitest::Test
  def test_parse_value
    parser = Parser.new(tokens: [])

    parser.instance_variable_set(:@current_token, Token.new(type: :INTEGER, value: "42"))

    assert_equal(parser.parse_value, 42)
  end
end
