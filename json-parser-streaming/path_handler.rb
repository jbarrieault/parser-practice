require "pry"
require "minitest"
require_relative "lexer"
require_relative "parser"

# This handler finds the value with the given path.
class PathHandler
  def initialize(path)
    @path = path
    @value = nil
    @current_event = nil
    @stack = []
  end

  attr_reader :path, :value, :current_event, :stack

  def handle(event)
    # I think I'll follow the same basic strategy as everything handler,
    # but with additional logic for knowing when the path's value has been completely handled.
    # At that point subsequent handle calls can noop.
    # I also don't need to build up the entire object, so if path is nested, ie `details.favorites[3].name`
    # we don't need to keep anything else in memory.
  end

  def to_ruby
    @value
  end
end

class PathHandlerTest < Minitest::Test
  def test_handle_array_index_path
    source = StringIO.new("[1,2,3]")
    lexer = Lexer.new(source)
    handler = PathHandler.new("[1]")
    emitter = Emitter.new(observers: [handler])
    parser = Parser.new(lexer:, emitter:)

    parser.parse

    assert_equal(2, handler.to_ruby)

  end
end
