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
    return if current_token.nil?

    case current_token.value
    when Lexer::LBRACE
      parse_object
    when Lexer::LBRACKET
      parse_array
    else
      parse_value
    end
  end

  private

  def parse_object
    expect(value: Lexer::LBRACE)

    obj = {}

    until current_token.nil? || current_token.value == Lexer::RBRACE
      key = parse_string
      advance
      expect(type: :SYMBOL, value: Lexer::COLON)
      val = parse
      expect(type: :SYMBOL, value: Lexer::COMMA) if current_token.value != Lexer::RBRACE
      obj[key] = val
    end

    expect(value: Lexer::RBRACE)

    obj
  end

  def parse_array
    expect(value: Lexer::LBRACKET)
    arr = []

    until current_token.nil? || current_token.value == Lexer::RBRACKET
      val = parse
      arr << val
      expect(type: :SYMBOL, value: Lexer::COMMA) if current_token.value != Lexer::RBRACKET
    end

    expect(value: Lexer::RBRACKET)

    arr
  end

  def parse_value
    val = case current_token.type
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

    advance
    val
  end

  def parse_string
    # the lexer preserves the surrounding quotes, but we need to get rid of them
    value = current_token.value
    unless value.length >= 2 && value.start_with?('"') && value.end_with?('"')
      raise ParseError, "Encountered STRING token with invalid value: #{value.inspect}"
    end

    value[1..-2]
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

  def expect(value: nil, type: nil)
    if value && current_token.value != value
      raise ParseError, "Expected token value #{value} at position #{position}, got: #{current_token.value}"
    end

    if type && current_token.type != type
      raise ParseError, "Expected token type #{type} at position #{position}, got: #{current_token.type}"
    end

    advance
  end
end

class ParserTest < Minitest::Test
  def test_parse_value
    parser = Parser.new(tokens: [])

    parser.instance_variable_set(:@current_token, Token.new(type: :INTEGER, value: "42"))

    assert_equal(42, parser.send(:parse_value))
  end

  def test_parse_with_integer
    token = Token.new(type: :INTEGER, value: "1")
    parser = Parser.new(tokens: [token])

    assert_equal(1, parser.parse)
  end

  def test_parse_with_float
    token = Token.new(type: :FLOAT, value: "3.14")
    parser = Parser.new(tokens: [token])

    assert_equal(3.14, parser.parse)
  end

  def test_parse_with_scientific_float
    token = Token.new(type: :FLOAT, value: "6.8e4")
    parser = Parser.new(tokens: [token])

    assert_equal(68000.0, parser.parse)
  end

  def test_parse_with_string
    token = Token.new(type: :STRING, value: '"b"')
    parser = Parser.new(tokens: [token])

    assert_equal("b", parser.parse)
  end

  def test_parse_with_empty_array
    tokens = [[:SYMBOL, "["], [:SYMBOL, "]"]].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = Parser.new(tokens:)

    assert_equal([], parser.parse)
  end

  def test_parse_with_single_value_array
    tokens = [[:SYMBOL, "["], [:INTEGER, 1], [:SYMBOL, "]"]].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = Parser.new(tokens:)

    assert_equal([1], parser.parse)
  end

  def test_parse_with_heterogeneous_array
    tokens = [[:SYMBOL, "["], [:INTEGER, "1"], [:SYMBOL, ","], [:STRING, "\"b\""], [:SYMBOL, ","], [:FLOAT, "3.14"], [:SYMBOL, "]"]].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = Parser.new(tokens:)

    assert_equal([1, "b", 3.14], parser.parse)
  end

  def test_parse_with_empty_object
    tokens = [[:SYMBOL, "{"], [:SYMBOL, "}"]].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = Parser.new(tokens:)

    assert_equal({}, parser.parse)
  end

  def test_parse_with_simple_object
    tokens = [
      [:SYMBOL, "{"],
      [:STRING, "\"first_name\""], [:SYMBOL, ":"], [:STRING, "\"Jacob\""], [:SYMBOL, ","],
      [:STRING, "\"last_name\""], [:SYMBOL, ":"], [:STRING, "\"Barrieault\""],
      [:SYMBOL, "}"]
    ].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = Parser.new(tokens:)

    assert_equal({ "first_name" => "Jacob", "last_name" => "Barrieault" }, parser.parse)
  end
end
