require "minitest/autorun"
require_relative "lexer"

class Node
  def to_ruby
    raise "Node subclass must implement to_ruby"
  end
end

class IntegerNode < Node
  def initialize(value)
    @value = value
  end

  def to_ruby
    @value.to_i
  end
end

class FloatNode < IntegerNode
  def to_ruby
    @value.to_f
  end
end

class StringNode < Node
  def initialize(value)
    @value = value
  end

  def to_ruby
    @value[1..-2]
  end
end

class ArrayNode < Node
  def initialize(elements)
    @elements = elements
  end

  def to_ruby
    @elements.map(&:to_ruby)
  end
end

class ASTParser
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

  end

  def parse_array
    expect(value: Lexer::LBRACKET)
    elements = []

    until current_token.nil? || current_token.value == Lexer::RBRACKET
      val = parse
      elements << val
      expect(type: :SYMBOL, value: Lexer::COMMA) if current_token.value != Lexer::RBRACKET
    end

    expect(value: Lexer::RBRACKET)

    ArrayNode.new(elements)
  end

  def parse_value
    val = case current_token.type
    when :INTEGER
      IntegerNode.new(current_token.value)
    when :FLOAT
      FloatNode.new(current_token.value)
    when :STRING
      parse_string
    end

    advance
    val
  end

  def parse_string
    value = current_token.value
    unless value.length >= 2 && value.start_with?('"') && value.end_with?('"')
      raise ParseError, "Encountered STRING token with invalid value: #{value.inspect}"
    end

    StringNode.new(value)
  end

  def advance
    @position += 1
    @current_token = tokens[position]
  end

  def expect(type: nil, value: nil)
    if value && current_token.value != value
      raise ParseError, "Expected token value #{value} at position #{position}, got: #{current_token.value}"
    end

    if type && current_token.type != type
      raise ParseError, "Expected token type #{type} at position #{position}, got: #{current_token.type}"
    end

    advance
  end
end

class ASTParserTest < Minitest::Test
  def test_parse_with_integer
    tokens = [Token.new(type: :INTEGER, value: "42")]
    parser = ASTParser.new(tokens:)
    node = parser.parse

    assert_instance_of IntegerNode, node
    assert_equal(42, node.to_ruby)
  end

  def test_parse_with_float
    tokens = [Token.new(type: :FLOAT, value: "3.14")]
    parser = ASTParser.new(tokens:)
    node = parser.parse

    assert_instance_of FloatNode, node
    assert_equal(3.14, node.to_ruby)
  end

  def test_parse_with_scientific_float
    token = [Token.new(type: :FLOAT, value: "6.8e4")]
    parser = ASTParser.new(tokens: token)
    node = parser.parse

    assert_instance_of FloatNode, node
    assert_equal(68000.0, node.to_ruby)
  end

  def test_parse_with_string
    tokens = [Token.new(type: :STRING, value: '"According to all known laws of aviation, there is no way a bee should be able to fly."')]
    parser = ASTParser.new(tokens:)
    node = parser.parse

    assert_instance_of StringNode, node
    assert_equal(
      "According to all known laws of aviation, there is no way a bee should be able to fly.",
      node.to_ruby
    )
  end

  def test_parse_with_empty_array
    tokens = [[:SYMBOL, "["], [:SYMBOL, "]"]].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = ASTParser.new(tokens:)
    node = parser.parse

    assert_instance_of(ArrayNode, node)
    assert_equal([], node.to_ruby)
  end

  def test_parse_with_single_value_array
    tokens = [[:SYMBOL, "["], [:INTEGER, 1], [:SYMBOL, "]"]].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = ASTParser.new(tokens:)
    node = parser.parse

    assert_instance_of(ArrayNode, node)
    assert_equal([1], node.to_ruby)
  end

  def test_parse_with_heterogeneous_array
    tokens = [[:SYMBOL, "["], [:INTEGER, "1"], [:SYMBOL, ","], [:STRING, "\"b\""], [:SYMBOL, ","], [:FLOAT, "3.14"], [:SYMBOL, "]"]].map do |(type, value)|
      Token.new(type:, value:)
    end

    parser = ASTParser.new(tokens:)
    node = parser.parse

    assert_instance_of(ArrayNode, node)
    assert_equal([1, "b", 3.14], node.to_ruby)
  end

end
