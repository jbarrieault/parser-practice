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
    @current_event = nil
    @stack = []
  end

  attr_reader :value, :current_event, :stack

  def handle(event)
    @current_event = event
    case event.type
    when Parser::ARRAY_START_EVENT
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
      arr = []
      @value = arr
      stack.push({ type: :array, value: arr })
    else
      state = stack.last
      if state[:type] == :array
        arr = []
        state[:value] << arr
        stack.push({ type: :array, value: arr })
      elsif state[:type] == :object
        arr = []
        state[:value][state[:next_key]] = arr
        stack.push({ type: :array, value: arr })
      else
        raise "wat"
      end
    end
  end

  def handle_array_end
    if @stack.last[:type] != :array
      raise "unexpected event value '#{current_event.value}', expected ']'"
    end

    stack.pop
  end

  def handle_object_start
    if @value.nil?
      obj = {}
      @value = obj
      stack.push({ type: :object, value: obj })
    else
      obj = {}
      state = stack.last
      if state[:type] == :array
        stack.push({ type: :object, value: obj })
      elsif state[:type] == :object
        state[:value][state[:next_key]] = obj
        stack.push({ type: :object, value: obj })
      else
        raise "wat"
      end
    end
  end

  def handle_object_key
    # this is just here for debugging—we trust the parser is giving us a valid document event stream
    if stack.last[:type] != :object
      raise "unexpected object key event value"
    end

    stack.last[:next_key] = current_event.value
  end

  def handle_object_end
    if stack.last[:type] != :object
      raise "unexpected event value '#{current_event.value}', expected '}'"
    end

    stack.pop
  end

  def handle_value(value)
    state = stack.last
    if @value.nil? # state.empty? ?
      @value = value
    elsif state[:type] == :array
      state[:value] << value
    elsif state[:type] == :object
      state[:value][state[:next_key]] = value
    else
      raise "wat"
    end
  end

  def to_ruby
    @value
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

  def test_handle_array
    source = StringIO.new("[1,2,3]")
    lexer = Lexer.new(source)
    handler = EverythingHandler.new
    emitter = Emitter.new(observers: [handler])
    parser = Parser.new(lexer:, emitter:)

    parser.parse

    assert_equal([1,2,3], handler.to_ruby)
  end

  def test_handle_object
    source = StringIO.new('{ "hello": "world" }')
    lexer = Lexer.new(source)
    handler = EverythingHandler.new
    emitter = Emitter.new(observers: [handler])
    parser = Parser.new(lexer:, emitter:)

    parser.parse

    assert_equal({ "hello" => "world" }, handler.to_ruby)
  end

  def test_nested_structures
    source = StringIO.new('{ "hello": "world", "numbers": [1,[2,3],4], "meta": { "data": true } }')
    lexer = Lexer.new(source)
    handler = EverythingHandler.new
    emitter = Emitter.new(observers: [handler])
    parser = Parser.new(lexer:, emitter:)

    parser.parse

    assert_equal({ "hello" => "world", "numbers" => [1,[2,3],4], "meta" => { "data" => true } }, handler.to_ruby)
  end
end

