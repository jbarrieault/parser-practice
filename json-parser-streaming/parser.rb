require 'pry'
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

class Parser
  def initialize(lexer:)
    @lexer = lexer
    @current_token = nil
  end

  attr_reader :lexer, :current_token

  def parse
    return if advance.nil?

    parse_value
  end

  def parse_value
    case current_token.type
    when :INTEGER
      emit(IntegerNode.new(current_token.value))
    when :FLOAT
      emit(FloatNode.new(current_token.value))
    when :STRING
      # parse_string
    end
  end

  def advance
    @current_token = lexer.next_token
  end

  def emit(node)
    # TODO
    @last_emit = node
  end
end

class ParserTest < Minitest::Test
  def test_parse_with_integer
    source = StringIO.new("42")
    lexer = Lexer.new(source)
    parser = Parser.new(lexer:)

    parser.parse
    node = parser.instance_variable_get(:@last_emit)

    assert_instance_of IntegerNode, node
    assert_equal(42, node.to_ruby)
  end
end
