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
  NULL_EVENT = "event:null"
  BOOL_EVENT = "event:bool"
  ARRAY_START_EVENT = "event:array_start"
  ARRAY_END_EVENT = "event:array_end"
  OBJECT_START_EVENT = "event:object_start"
  OBJECT_END_EVENT = "event:object_end"

  def initialize(lexer:, emitter:)
    @lexer = lexer
    @emitter = emitter
    @current_token = nil
    @stack = []
  end

  attr_reader :lexer, :current_token, :emitter, :stack

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

    case current_token&.value
    when nil
      # An array or object is un-closed)
      raise ParseError, "unexpected end of input: stack not empty" if stack.size > 0
    when Lexer::LBRACKET
      parse_array_start
    when Lexer::RBRACKET
      parse_array_end
    when Lexer::LBRACE
      parse_object_start
    when Lexer::RBRACE
      parse_object_end
    when Lexer::COMMA
      parse_comma
      # an event is not emitted for commas, so parse_next again
      # in order to preserve the behavior of 1 public call to #next_token emitting an event.
      parse_next
    else
      parse_value
    end
  end

  def parse_array_start
    must_expect!(:value)
    stack.push({ type: :array, expecting: [:value, :array_end] })
    emit(Event.new(type: ARRAY_START_EVENT, value: current_token.value))
  end

  def parse_array_end
    must_expect!(:array_end)
    stack.pop
    emit(Event.new(type: ARRAY_END_EVENT, value: current_token.value))
  end

  def parse_object_start
    must_expect!(:value)
    stack.push({ type: :object, expecting: [:key, :object_end] })
    emit(Event.new(type: OBJECT_START_EVENT, value: current_token.value))
  end

  def parse_object_end
    must_expect!(:object_end)
    stack.pop
    emit(Event.new(type: OBJECT_END_EVENT, value: current_token.value))
  end

  def parse_value
    must_expect!(:value)

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
    when :NULL
      emit(Event.new(type: NULL_EVENT, value: nil))
    when :BOOL
      value = current_token.value == "true"
      emit(Event.new(type: BOOL_EVENT, value:))
    end

    state[:expecting] = [:comma, :array_end] if state[:type] == :array
    # state[:expecting] = [:comma, :end_object] if state[:type] == :object
  end

  def parse_comma
    must_expect!(:comma)

    if state[:type] == :array
      state[:expecting] = [:value]
    # elsif state[:type] == :object
    #   state[:expecting] = [:key, :value]
    end
  end

  def state
    stack.last || {}
  end

  def advance
    @current_token = lexer.next_token
  end

  def emit(event)
    emitter.emit(event)
  end

  # validate that `type` is one of we're currently `expecting`
  def must_expect!(type)
    expecting = state[:expecting]
    return if expecting.nil?

    unless expecting.include?(type)
      raise ParseError, "Unexpected #{type} '#{current_token.value}', expecting any of: #{expecting.join(', ')}"
    end
  end
end

class ParserTest < Minitest::Test
  def test_parse_value_with_integer
    source = StringIO.new("42")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.advance
    parser.parse_value
    event = observer.events.last

    assert_equal(1, observer.events.size)
    assert_equal([Parser::INTEGER_EVENT, 42], event.to_a)
  end

  def test_parse_value_with_string
    source = StringIO.new("\"Hello\"")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.advance
    parser.parse_value
    event = observer.events.last

    assert_equal(1, observer.events.size)
    assert_equal([Parser::STRING_EVENT, "Hello"], event.to_a)
  end

  def test_parse_value_with_null
    source = StringIO.new("null")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.advance
    parser.parse_value
    event = observer.events.last

    assert_equal(1, observer.events.size)
    assert_equal([Parser::NULL_EVENT, nil], event.to_a)
  end

  def test_parse_value_with_bool
    source = StringIO.new("true")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.advance
    parser.parse_value
    event = observer.events.last

    assert_equal(1, observer.events.size)
    assert_equal([Parser::BOOL_EVENT, true], event.to_a)
  end

  def test_parse_next_array
    source = StringIO.new("[[1,2]]")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.parse_next
    assert_equal([Parser::ARRAY_START_EVENT, "["], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::ARRAY_START_EVENT, "["], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::INTEGER_EVENT, 1], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::INTEGER_EVENT, 2], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::ARRAY_END_EVENT, "]"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::ARRAY_END_EVENT, "]"], observer.events.last.to_a)
  end

  def test_parse_next_object
    source = StringIO.new("{}")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.parse_next
    assert_equal([Parser::OBJECT_START_EVENT, "{"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_END_EVENT, "}"], observer.events.last.to_a)
  end
end
