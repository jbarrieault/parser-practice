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

  end

  def parse_value
    val = case current_token.type
    when :INTEGER
      IntegerNode.new(current_token.value)
    end

    advance
    val
  end

  def advance
    @position += 1
    @current_token = tokens[position]
  end
end

class ASTParserTest < Minitest::Test
  def test_parse_value
    parser = ASTParser.new(tokens: [])
    parser.instance_variable_set(:@current_token, Token.new(type: :INTEGER, value: "42"))
    node = parser.send(:parse_value)

    assert_instance_of IntegerNode, node
    assert_equal(42, node.to_ruby)
  end
end
