class Block
  attr_reader :defined_values

  GLOBALS = {
    '+' => lambda { |a,b| a + b },
    '*' => lambda { |a,b| a * b },
    '/' => lambda { |a,b| a / b },
    '-' => lambda { |a,b| a - b },
    # '=' is defined in .evaluate
    # '.' is defined in .evaluate
  }

  def initialize(defined_values = nil)
    @defined_values = defined_values || GLOBALS

    # Time for a hack!
    if defined_values.nil?
      @defined_values.merge!({
        'HTTPServer' => Block.new(GLOBALS.merge({
          'get' => lambda { |path, fn| nil },
          'start!' => lambda { puts 'Server started. Kinda.' }
        }))
      })
    end

    @defined_values
  end

  def assign(id, value)
    raise "Cannot redefine #{id}!" if @defined_values[id]
    @defined_values[id] = value
  end

  def evaluate_return_last(exprs)
    return_value = nil
    exprs.each do |expr|
      return_value = evaluate(expr)
    end

    # If nothing is returned from the block,
    # return the whole block.
    return_value || self
  end

  def evaluate_return_block(exprs)
    exprs.each do |expr|
      evaluate(expr)
    end

    self
  end

  def evaluate(expr)
    case expr.class.name
    when 'NumberExpr'
      expr.value.to_i
    when 'StringExpr'
      expr.value.to_s
    when 'IdentifierExpr'
      # Identifier call!
      @defined_values[expr.name] || puts("What is #{expr.name}?")
    when 'FunctionCallExpr'
      evaluate_function_call(expr)
    when 'FunctionPrototypeExpr'
      evaluate_function_prototype(expr)
    when 'BlockExpr'
      evaluate_block(expr)
    when 'ImportExpr'
      @defined_values.merge!(@defined_values[expr.name].defined_values)
    else
      puts "I can't evaluate a #{expr.class}!"
    end
  end

  def evaluate_function_call(expr)
    # Function call!
    name = expr.reference.name

    # Special case: assignment
    if name == '='
      assign(expr.args[0].name, evaluate(expr.args[1]))
    # Special case: dereference
    elsif name == '.'
      scope = evaluate(expr.args[0])
      scope.evaluate(expr.args[1])
    else
      f = @defined_values[expr.reference.name]

      puts "What is #{name}?" unless f
      puts "#{name} is not a function" unless f.respond_to? :call

      f.call(*expr.args.map { |arg| evaluate(arg) })
    end
  end

  def evaluate_function_prototype(expr)
    lambda do |*call_args|
      arg_ids = expr.args
      unless arg_ids.length == call_args.length
        puts "Expected #{arg_ids.length} args, got #{call_args.length}"
      end

      body = expr.body

      # Setup function scope
      arg_scope = arg_ids.each_with_index.reduce({}) do |memo, (arg, idx)|
        memo[arg.name] = call_args[idx]
        memo
      end

      function_scope = Block.new(@defined_values.merge(arg_scope))

      # Evaluate the function
      function_scope.evaluate_return_last(expr.body)
    end
  end

  def evaluate_block(expr)
    block_scope = Block.new(@defined_values)

    # Evaluate the function
    block_scope.evaluate_return_block(expr.body)
  end

end