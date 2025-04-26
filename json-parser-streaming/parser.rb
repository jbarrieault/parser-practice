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
  OBJECT_KEY_EVENT = "event:object_key"

  def initialize(lexer:, emitter:)
    @lexer = lexer
    @emitter = emitter
    @current_token = nil
    @stack = [{ type: :top, expecting: [:value] }]
  end

  attr_reader :lexer, :current_token, :emitter, :stack

  def parse
    loop do
      parse_next
      break if current_token.nil?
    end
  end

  # re-entrant API: only emits 1 event per call
  def parse_next
    advance

    case current_token&.value
    when nil
      # An array or object is un-closed)
      raise ParseError, "unexpected end of input: stack not empty" if state[:type] != :top
      return nil
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
      if current_token.type == :STRING
        parse_string
      else
        parse_value
      end
    end

    true
  end

  def parse_array_start
    must_expect!(:value)
    stack.push({ type: :array, expecting: [:value, :array_end] })
    emit(type: ARRAY_START_EVENT, value: current_token.value)
  end

  def parse_array_end
    must_expect!(:array_end)
    stack.pop
    update_state_expecting_to_comma_or_end

    emit(type: ARRAY_END_EVENT, value: current_token.value)
  end

  def parse_object_start
    must_expect!(:value)
    stack.push({ type: :object, expecting: [:key, :object_end] })
    emit(type: OBJECT_START_EVENT, value: current_token.value)
  end

  def parse_object_end
    must_expect!(:object_end)
    stack.pop
    update_state_expecting_to_comma_or_end

    emit(type: OBJECT_END_EVENT, value: current_token.value)
  end

  def parse_string
    if state[:expecting]&.include?(:key)
      parse_key
    else
      parse_string_value
    end
  end

  def parse_string_value
    must_expect!(:value)
    update_state_expecting_to_comma_or_end
    emit(type: STRING_EVENT, value: current_token.value[1..-2])
  end

  def parse_key
    must_expect!(:key)

    if current_token.type != :STRING
      raise ParseError, "Unexpected token '#{current_token.value}', expected string for object key"
    end

    value = current_token.value[1..-2]

    advance
    if current_token.to_a != [:SYMBOL, ":"]
      raise ParseError, "Unexpected token '#{current_token.value}', expected ':' for object key"
    end

    state[:expecting] = [:value]

    emit(type: OBJECT_KEY_EVENT, value:)
  end

  def parse_value
    must_expect!(:value)

    event = case current_token.type
    when :INTEGER
      { type: INTEGER_EVENT, value: current_token.value.to_i }
    when :FLOAT
      { type: FLOAT_EVENT, value: current_token.value.to_f }
    when :NULL
      { type: NULL_EVENT, value: nil }
    when :BOOL
      { type: BOOL_EVENT, value: current_token.value == "true" }
    else
      raise ParseError, "Unexpected token '#{current_token.value}' (type #{current_token.type}), expecting a value."
    end

    update_state_expecting_to_comma_or_end

    emit(**event)
  end

  def update_state_expecting_to_comma_or_end
    state[:expecting] = [:comma, :array_end] if state[:type] == :array
    state[:expecting] = [:comma, :object_end] if state[:type] == :object
    state[:expecting] = [:eof] if state[:type] == :top
  end

  def parse_comma
    must_expect!(:comma)

    if state[:type] == :array
      state[:expecting] = [:value]
    elsif state[:type] == :object
      state[:expecting] = [:key]
    end
  end

  def state
    stack.last
  end

  def advance
    @current_token = lexer.next_token
  end

  def emit(type:, value:)
    emitter.emit(Event.new(type:, value:))
  end

  # validate that `type` is one of we're currently `expecting`
  def must_expect!(type)
    expecting = state[:expecting]

    unless expecting.include?(type)
      raise ParseError, "Unexpected token '#{current_token.value}' (type #{type}), expecting any of: #{expecting.join(', ')}"
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

  def test_parse_string_value
    source = StringIO.new("\"Hello\"")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.advance
    parser.parse_string_value
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
    source = StringIO.new(
      <<~JSON
        {
          "hello": "world",
          "hobbies": ["programming", "pickleball", "bicycling", "music"],
          "detail": {
            "ts": 123456,
            "args": [1, "16", true]
          }
        }
      JSON
    )
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    parser.parse_next
    assert_equal([Parser::OBJECT_START_EVENT, "{"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_KEY_EVENT, "hello"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::STRING_EVENT, "world"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_KEY_EVENT, "hobbies"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::ARRAY_START_EVENT, "["], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::STRING_EVENT, "programming"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::STRING_EVENT, "pickleball"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::STRING_EVENT, "bicycling"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::STRING_EVENT, "music"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::ARRAY_END_EVENT, "]"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_KEY_EVENT, "detail"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_START_EVENT, "{"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_KEY_EVENT, "ts"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::INTEGER_EVENT, 123456], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_KEY_EVENT, "args"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::ARRAY_START_EVENT, "["], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::INTEGER_EVENT, 1], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::STRING_EVENT, "16"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::BOOL_EVENT, true], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::ARRAY_END_EVENT, "]"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_END_EVENT, "}"], observer.events.last.to_a)

    parser.parse_next
    assert_equal([Parser::OBJECT_END_EVENT, "}"], observer.events.last.to_a)
  end

  def test_only_one_top_level_value
    source = StringIO.new("[1],2")
    lexer = Lexer.new(source)
    observer = MemoryObserver.new
    emitter = Emitter.new(observers: [observer])
    parser = Parser.new(lexer:, emitter:)

    err = assert_raises(Parser::ParseError) do
      parser.parse
    end

    assert_match "Unexpected token ',' (type comma), expecting any of: eof", err.message
  end
end
