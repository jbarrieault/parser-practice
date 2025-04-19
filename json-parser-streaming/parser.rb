require 'pry'
require "minitest/autorun"
require_relative "lexer"

class Emitter
  def initialize
    @events = []
  end

  def emit(event)
    @events << event
  end

  def last_event
    @events.last
  end
end

class Event
  def initialize(type:, value:)
    @type = type
    @value = value
  end

  def to_a
    [@type, @value]
  end
end

class Parser
  INTEGER_EVENT = "event:integer"
  FLOAT_EVENT = "event:float"

  def initialize(lexer:)
    @lexer = lexer
    @current_token = nil
    @emitter = Emitter.new
  end

  attr_reader :lexer, :current_token, :emitter

  def parse
    return if advance.nil?

    parse_value
  end

  def parse_value
    case current_token.type
    when :INTEGER
      value = current_token.value.to_i
      emit(Event.new(type: INTEGER_EVENT, value:))
    when :FLOAT
      value = current_token.value.to_f
      emit(Event.new(type: FLOAT_EVENT, value:))
    when :STRING
      # parse_string
    end
  end

  def advance
    @current_token = lexer.next_token
  end

  def emit(node)
    emitter.emit(node)
  end
end

class ParserTest < Minitest::Test
  def test_parse_with_integer
    source = StringIO.new("42")
    lexer = Lexer.new(source)
    parser = Parser.new(lexer:)

    parser.parse
    event = parser.emitter.last_event

    assert_equal([Parser::INTEGER_EVENT, 42], event.to_a)
  end
end
