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
    @buffer = nil
  end

  def handle(event)
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
    @value = []
  end

  def handle_array_end
    :noop
  end

  def handle_value(value)
    if @value.is_a? Array
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
    source = StringIO.new("[123]")
    lexer = Lexer.new(source)
    handler = EverythingHandler.new
    emitter = Emitter.new(observers: [handler])
    parser = Parser.new(lexer:, emitter:)

    parser.parse

    assert_equal([123], handler.to_ruby)
  end
end

