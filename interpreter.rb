require './tokeniser'
require './parser'

tokens = Tokeniser.tokenise(File.read('example.fn'))
puts tokens
tree = Parser.parse(tokens)
puts tree.compact
