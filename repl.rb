require './tokeniser'
require './parser'
require './runtime'

def execute(runtime, line)
  tokens = Tokeniser.tokenise(line)
  tree = Parser.parse(tokens)
  runtime.evaluate_return_last(tree)
end

runtime = Block.new

loop do
  print '> '
  line = gets.chomp
  puts execute(runtime, line)
end
