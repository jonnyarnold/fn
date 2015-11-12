require './tokeniser'
require './parser'
require './runtime'

def execute(runtime, line)
  tokens = Tokeniser.tokenise(line)
  tree = Parser.parse(tokens)
  runtime.eval(tree)
end

runtime = TopLevelScope.new

loop do
  print '> '
  line = gets.chomp

  begin
    puts execute(runtime, line).to_s
  rescue FnRunError => e
    puts e
  end
end
