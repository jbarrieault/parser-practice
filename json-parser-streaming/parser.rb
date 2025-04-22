require 'pry'
require "minitest/autorun"
require_relative "lexer"

class Emitter
  def initialize(observers: [])
    @observers = observers
  end

  attr_reader :observers

  def emit(event)
    observers.each do |observer|
      observer.handle(event)
    end
  end
end

class MemoryObserver
  def initialize
    @events = []
  end

  attr_reader :events

  def handle(event)
    events << event
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
  class ParseError < StandardError; end

  INTEGER_EVENT = "event:integer"
  FLOAT_EVENT = "event:float"
  STRING_EVENT = "event:string"
  ARRAY_START_EVENT = "event:array_start"
  ARRAY_END_EVENT = "event:array_end"

  def initialize(lexer:, emitter:)
    @lexer = lexer
    @emitter = emitter
    @current_token = nil
    @stack = []
    @expecting = :value
  end

  attr_reader :lexer, :current_token, :emitter, :stack, :expecting

  def parse
    return if advance.nil?

    if current_token.value == Lexer::LBRACKET
      parse_array
    elsif current_token.value == Lexer::RBRACE
      # TODO
      # parse_object
    else
      parse_value
    end
  end

  # re-entrant API: only emits 1 event per call
  def parse_next
    advance

    if current_token.nil?
      # error if: @stack isn't empty (something is un-closed)
      raise ParseError, "unexpected end of input: stack not empty" if stack.size > 0
      return
    end

    if current_token.value == Lexer::LBRACKET

      parse_array_start
    end
  end

  def parse_array_start
    expect!(:value)
    stack.push(:array)
    expecting = :value # :value_or_bracket

    emit(Event.new(type: ARRAY_START_EVENT, value: current_token.value))
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
      value = current_token.value[1..-2]
      emit(Event.new(type: STRING_EVENT, value:))
    end
  end

  def advance
    @current_token = lexer.next_token
  end

  def emit(event)
    emitter.emit(event)
  end

  def expect!(type_being_parsed)
    if type_being_parsed != expecting
      raise ParseError, "Expecting to parse a #{expecting}, but parsing a #{type_being_parsed}"
    end
  end
end

class ParserTest < Minitest::Test
  def test_parse_with_integer
    source = StringIO.new("42")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.parse
    event = observer.events.last

    assert_equal(1, observer.events.size)
    assert_equal([Parser::INTEGER_EVENT, 42], event.to_a)
  end

  def test_parse_with_string
    source = StringIO.new("\"Hello\"")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.parse
    event = observer.events.last

    assert_equal(1, observer.events.size)
    assert_equal([Parser::STRING_EVENT, "Hello"], event.to_a)
  end

  def test_parse_next_array_start
    source = StringIO.new("[")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.parse_next
    event = observer.events.last

    # test what was emitted
    assert_equal(1, observer.events.size)
    assert_equal([Parser::ARRAY_START_EVENT, "["], event.to_a)

    # test state transition
    assert_equal([:array], parser.stack)
    assert_equal(:value, parser.expecting)
  end
end
