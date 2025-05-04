require "pry"
require "minitest"
require_relative "lexer"
require_relative "parser"

# This handler observes events emitted by the parser and constructs
# the corresponding Ruby value(s).
# In reality this defeats the purpose of a SAX-like parser, but hey.
class EverythingHandler
  def initialize
    @value = nil
    @cursor = nil
    @current_event = nil
    @stack = [{ type: :top, buffer: nil } ]
  end

  attr_reader :value, :current_event, :stack

  def handle(event)
    @current_event = event
    case event.type
    when Parser::ARRAY_START_EVENT
      # left off: this is the start of a value that needs to be either:
      # 1. the top-level value of the doc
      # 2. shoveled into a currently open array
      # 3. added to currently object object
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
      handle_value(event.value)
    end
  end

  def handle_array_start
    if @value.nil?
      @value = @cursor = []
    else
      next_cursor = []
      if stack.last[:type] == :array
        puts "BACON current_event: #{current_event.value}"
        puts "BACON stack.last: #{stack.last}"
        @cursor << next_cursor
        @cursor = next_cursor
      elsif stack.last[:type] == :object
        @cursor[stack.last[:buffer]] = next_cursor
        @cursor = next_cursor
      else
        raise "wat"
      end
    end

    @stack << { type: :array }
  end

  def handle_array_end
    if @stack.last[:type] != :array
      raise "unexpected event value '#{current_event.value}', expected ']'"
    end

    # we're screwed—we don't know how to move the cursor up the the current arrays's parent
    # that tells me that each @stack entry needs a cursor?
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

  def handle_value(value)
    state = stack.last
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
    @value
  end
end

class EverythingHandlerTest < Minitest::Test
  # def test_handle_integer
  #   source = StringIO.new("1")
  #   lexer = Lexer.new(source)
  #   handler = EverythingHandler.new
  #   emitter = Emitter.new(observers: [handler])
  #   parser = Parser.new(lexer:, emitter:)

  #   parser.parse

  #   assert_equal(1, handler.to_ruby)
  # end

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

  def test_nested_structures
    source = StringIO.new('{ "hello": "world", "numbers": [1,2,3] }')
    lexer = Lexer.new(source)
    handler = EverythingHandler.new
    emitter = Emitter.new(observers: [handler])
    parser = Parser.new(lexer:, emitter:)

    parser.parse

    assert_equal({ "hello" => "world", "numbers" => [1,2,3] }, handler.to_ruby)
  end
end

