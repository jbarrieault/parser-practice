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
  end

  def handle(event)
    case event.type
    when Parser::INTEGER_EVENT
      @value = event.value
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
end

