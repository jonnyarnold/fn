class FnRunError < StandardError
end

class Block
  attr_reader :defined_values, :call_proc

  GLOBALS = {
    '+' => lambda { |a,b| a + b },
    '*' => lambda { |a,b| a * b },
    '/' => lambda { |a,b| a / b },
    '-' => lambda { |a,b| a - b },
    'and' => lambda { |a,b| a && b },
    'or' => lambda { |a,b| a || b },
    # '=' is defined in .evaluate
    # '.' is defined in .evaluate
  }

  def initialize(defined_values = nil, call_proc = nil)
    set_defined_values(defined_values)
    @call_proc = call_proc
    @scope_values = {}
  end

  def set_defined_values(defined_values)
    @defined_values = defined_values || GLOBALS
    @defined_values['self'] = self

    # Time for a hack!
    if defined_values.nil?
      @defined_values.merge!({
        'HTTPServer' => Block.new(GLOBALS.merge({
          'get' => lambda { |path, fn| nil },
          'start!' => lambda { puts 'Server started. Kinda.' }
        }))
      })
    end
  end

  def to_s(level=0)
    level_spaces = ' ' * level
    out = ''

    out += "() " unless @call_proc.nil?

    if @scope_values.length == 0
      out += '{}'
      return out
    end

    out += "{\n" + level_spaces
    @scope_values.each do |k,v|
      if v.is_a? Block
        out += "  #{k} = #{v.to_s(level + 2)}\n" + level_spaces
      else
        out += "  #{k} = #{v}\n" + level_spaces
      end
    end
    out += '}'

    out
  end

  def assign(id, value)
    raise FnRunError.new("Cannot redefine #{id}!") if @defined_values[id]
    @defined_values[id] = value
    @scope_values[id] = value
  end

  def call(*args)
    @call_proc.call(*args)
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
    when 'BooleanExpr'
      expr.value == 'true'
    when 'IdentifierExpr'
      # Identifier call!
      raise(FnRunError.new("Unknown identifier #{expr.name}")) unless @defined_values.key? expr.name
      @defined_values[expr.name]
    when 'FunctionCallExpr'
      evaluate_function_call(expr)
    when 'FunctionPrototypeExpr'
      evaluate_function_prototype(expr)
    when 'BlockExpr'
      evaluate_block(expr)
    when 'ConditionalExpr'
      evaluate_condition(expr)
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
      raise FnRunError.new("Non-block on left-hand side of `.`") unless scope.is_a? Block

      scope.evaluate(expr.args[1])
    else
      f = @defined_values[expr.reference.name]
      raise FnRunError.new("#{name} is not a function") unless callable?(f)

      f.call(*expr.args.map { |arg| evaluate(arg) })
    end
  end

  # Callable is:
  #  - A lambda (built-in)
  #  - A Block with a call_proc
  def callable?(obj)
    # Both of these objects response do call
    return true if obj.respond_to? :call
  end

  def evaluate_function_prototype(expr)
    Block.new(@defined_values, lambda do |*call_args|
      arg_ids = expr.args
      unless arg_ids.length == call_args.length
        raise FnRunError.new("Expected #{arg_ids.length} args, got #{call_args.length}")
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
    end)
  end

  def evaluate_block(expr)
    block_scope = Block.new(@defined_values)

    # Evaluate the function
    block_scope.evaluate_return_block(expr.body)
  end

  def evaluate_condition(expr)
    expr.branches.each do |branch|
      result = evaluate(branch.condition)
      if result
        return evaluate_return_last(branch.body.body)
      end
    end
  end

end
