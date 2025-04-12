# README

This directory contains a couple of 'eager' JSON parser implementations.

All input is read into memory at once by both the lexer and parser. `Parser` produces a Ruby representation of the input directly, and `AstParser` produces an (surprise) AST representing the parsed document.
