require './tokeniser'
require './parser'
require './runtime'

tokens = Tokeniser.tokenise(File.read('tour.fn'))
tree = Parser.parse(tokens)

runtime = TopLevelScope.new
runtime.eval(tree)
