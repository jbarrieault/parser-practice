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
    when *Parser::VALUE_EVENTS
      handle_value(event.value)
    end
  end

  def handle_array_start
    @stack << '['
    @value = []
  end

  def handle_array_end
    if @stack.last != '['
      raise "unexpected event value '#{current_event.value}', expected ']'"
    end

    stack.pop
    :noop
  end

  def handle_value(value)
    if @stack.last == '['
      @value << value
    else
      @value = value
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
end

