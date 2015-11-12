require './tokeniser'
require './parser'
require './runtime'

def execute(runtime, line)
  tokens = Tokeniser.tokenise(line)
  tree = Parser.parse(tokens)
  runtime.evaluate_return_last(tree)
end

runtime = Block.new

# Keep asking for lines!
loop do
  print 'fn> '
  line = gets.chomp

  # Try to execute the line;
  # if it doesn't work, assume the user wants to continue.
  # FIXME: this makes syntax errors look like continuation requests...
  loop do
    runtime_sandbox = runtime.clone

    begin
      puts execute(runtime_sandbox, line)

      # Successful execution; set the runtime to the sandbox.
      runtime = runtime_sandbox
      break
    rescue FnRunError => e
      # It ran, but ended in a Fn failure.
      puts e
      break
    rescue StandardError => e
      # The Parser errored. Keep asking!
      print '... '
      line += gets.chomp
    end
  end
end
