require './tokeniser'
require './parser'

tokens = Tokeniser.tokenise(File.read('example.fn'))
tree = Parser.parse(tokens)
puts tree.compact
