require './tokeniser'
require './parser'
require './runtime'

tokens = Tokeniser.tokenise(File.read('tour.fn'))
tree = Parser.parse(tokens)

runtime = Block.new
tree.each do |expr|
  runtime.evaluate(expr)
end
