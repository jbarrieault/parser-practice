require "pry"
require "minitest"
require_relative "lexer"
require_relative "parser"

# This handler observes events emitted by the parser and constructs
# the corresponding Ruby value(s).
# In reality this defeats the purpose of a SAX-like parser, but hey.

class Node
  def initialize(value)
    @value = value
  end

  attr_accessor :parent

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
  def initialize(elements = nil)
    @elements = elements || []
  end

  def add_child(node)
    @elements << node
    node.parent = self
  end

  def to_ruby
    @elements.map(&:to_ruby)
  end
end

class ObjectNode < Node
  def initialize(pairs)
    @pairs = pairs
  end

  attr_accessor :next_key

  def to_ruby
    @pairs.map { |k, v| [k.to_ruby, v.to_ruby] }.to_h

    # WIP: store key/val pairs as ObjectEntry nodes
    # @entries.reduce({}) do |acc, entry|
    #   { **acc, **entry.to_ruby }
    # end
  end
end

# TODO: should this be a node type?
class ObjectEntryNode < Node
  def initialize(key)
    @key = key
  end

  def value=(node)
    @value_set = true
    @value = node
  end

  def to_ruby
    if @value_set
      { key.to_ruby => value.to_ruby }
    else
      raise "ObjectEntryNode must have a value set!"
    end
  end
end


class EverythingHandler
  def initialize
    @value = nil
    @cursor = nil
    @current_event = nil
    @root_node = nil
    @current_node = nil
  end

  attr_reader :value, :current_event, :stack

  def handle(event)
    @current_event = event
    case event.type
    when Parser::ARRAY_START_EVENT
      # left off: this is the start of a value that needs to be either:
      # 1. the top-level value of the doc
      # 2. shoveled into a currently open array
      # 3. added to currently open object
      # so maybe this class should be scrapped to build an actual AST
      # then handle_array_start would be more like:
      # node =  ArrayNode.new(event)
      # @current_node.add_child(node)
      # @current_node = node
      # and closing arrays & objects would re-set @current_node to @current_node.parent
      handle_array_start
    when Parser::ARRAY_END_EVENT
      handle_array_end
    when Parser::OBJECT_START_EVENT
      handle_object_start
    when Parser::OBJECT_KEY_EVENT
      handle_object_key
    when Parser::OBJECT_END_EVENT
      handle_object_end
    when *Parser::VALUE_EVENTS
      handle_value(event)
    end
  end

  def handle_array_start
    if @value.nil?
      @value = @cursor = []
    else
      if current_node.is_a?(ArrayNode)
        # Add this array as a child
      elsif current_node.is_a?(ObjectNode)
        # add this object as value to the current (expected to exist) key
        # so maybe the elsif should be checking for ObjectEntryNode?
      elsif current_node.nil?
        # create root/current node
      else
        # wat?
      end

      # next_cursor = []
      # if stack.last[:type] == :array
      #   puts "BACON current_event: #{current_event.value}"
      #   puts "BACON stack.last: #{stack.last}"
      #   @cursor << next_cursor
      #   @cursor = next_cursor
      # elsif stack.last[:type] == :object
      #   @cursor[stack.last[:buffer]] = next_cursor
      #   @cursor = next_cursor
      # else
      #   raise "wat"
      # end
    end

    # @stack << { type: :array }
  end

  def handle_array_end
    if @stack.last[:type] != :array
      raise "unexpected event value '#{current_event.value}', expected ']'"
    end

    stack.pop
  end

  def handle_object_start
    if @value.nil?
      @value = @cursor = {}
    else
      next_cursor = {}
      if stack.last[:type] == :array
        @cursor << next_cursor
        @cursor = next_cursor
      elsif stack.last[:type] == :object
        @cursor[stack.last[:buffer]] = next_cursor
        @cursor = next_cursor
      else
        raise "wat"
      end
    end

    stack << { type: :object }
  end

  def handle_object_key
    if stack.last[:type] != :object
      raise "unexpected object key event value"
    end

    stack.last[:buffer] = current_event.value
  end

  def handle_object_end
    if stack.last[:type] != :object
      raise "unexpected event value '#{current_event.value}', expected '}'"
    end

    # we're screwed—we don't know how to move the cursor up the the current object's parent
    stack.pop
  end

  def handle_value(event)
    node = case event.type
    when :INTEGER
      IntegerNode.new(event.value)
    when :FLOAT
      FloatNode.new(event.value)
    when :STRING
      parse_string
    end

    if current_node.nil?
      current_node = node
    elsif current_node.is_a?(ArrayNode)
      current_node.add_child(node)
    elsif current_node.is_a?(ObjectNode)
      if current_node.next_key.nil?
        # not sure I expect to ever end up here
        current_node.next_key = event.value

      elsif current_node.next_key.present?
        current_node.value = event.value
        current_node.pairs
      end
    else
      raise "unexpected value, current_node (a #{current_node.class}) is terminal"
    end


    if state[:type] == :array
      @cursor << value
    elsif state[:type] == :object
      key = state[:buffer]
      @cursor[key] = value
    else
      @value = @cursor = value
    end
  end


  def to_ruby
    @root_node.to_ruby
  end
end

class EverythingHandlerTest < Minitest::Test
  def test_handle_integer
    source = StringIO.new("1")
    lexer = Lexer.new(source)
    handler = EverythingHandler.new
    emitter = Emitter.new(observers: [handler])
    parser = Parser.new(lexer:, emitter:)

    parser.parse

    assert_equal(1, handler.to_ruby)
  end

  # def test_handle_array
  #   source = StringIO.new("[1,2,3]")
  #   lexer = Lexer.new(source)
  #   handler = EverythingHandler.new
  #   emitter = Emitter.new(observers: [handler])
  #   parser = Parser.new(lexer:, emitter:)

  #   parser.parse

  #   assert_equal([1,2,3], handler.to_ruby)
  # end

  # def test_handle_object
  #   source = StringIO.new('{ "hello": "world" }')
  #   lexer = Lexer.new(source)
  #   handler = EverythingHandler.new
  #   emitter = Emitter.new(observers: [handler])
  #   parser = Parser.new(lexer:, emitter:)

  #   parser.parse

  #   assert_equal({ "hello" => "world" }, handler.to_ruby)
  # end

  # def test_nested_structures
  #   source = StringIO.new('{ "hello": "world", "numbers": [1,[2],3] }')
  #   lexer = Lexer.new(source)
  #   handler = EverythingHandler.new
  #   emitter = Emitter.new(observers: [handler])
  #   parser = Parser.new(lexer:, emitter:)

  #   parser.parse

  #   assert_equal({ "hello" => "world", "numbers" => [1,[2],3] }, handler.to_ruby)
  # end
end

