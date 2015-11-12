class FnRunError < StandardError
end

# A Scope is a runtime environment that enfores lexical scoping.
# Everything is a Scope in Fn.
class Scope
  attr_reader :scope_attributes

  # Constructor.
  # A parent Scope can be defined.
  def initialize(parent)
    @parent = parent
    @scope_attributes = {}
  end

  # Defines a new ID in this Scope.
  #
  # Scopes can redefine names in parent Scopes,
  # but cannot redefine names in the current Scope.
  def assign(id, value)
    raise FnRunError.new("Cannot redefine #{id}!") if @scope_attributes[id]
    @scope_attributes[id] = value

    nil
  end

  # Gets the value of the given ID.
  def get(id)
    value = attributes[id]
    raise(FnRunError.new("Unknown identifier #{id}")) unless value

    value
  end

  # Perform the function call specified in this Scope.
  # Raises an error if no function has been defined.
  def call(*args)
    proc = @scope_attributes['call'] 
    raise FnRunError.new("Not callable. Define 'call'!") unless proc

    proc.call(*args)
  end

  # Get the internal value of this scope.
  def value
    fail 'Asked for value on a non-value scope.'
  end

  # The attributes this Scope can access.
  def attributes
    parent_attributes.merge(scope_attributes)
  end

  # Evaluates the given expressions in the Scope.
  def eval(exprs)
    return_value = nil
    exprs.each do |expr|
      return_value = eval_one(expr)
    end

    # If nothing is returned from the block,
    # return the whole block.
    return_value || self
  end

  # Evaluates a single expression in the Scope.
  def eval_one(expr)
    case expr.class.name
    when 'NumberExpr'
      NumberScope.new(self, expr.value.to_f)
    when 'StringExpr'
      StringScope.new(self, expr.value.to_s)
    when 'BooleanExpr'
      ValueScope.new(self, expr.value == 'true')
    when 'ListExpr'
      evaluate_list(expr)
    when 'IdentifierExpr'
      get(expr.name)
    when 'FunctionCallExpr'
      evaluate_function_call(expr)
    when 'FunctionPrototypeExpr'
      evaluate_function_prototype(expr)
    when 'BlockExpr'
      evaluate_block(expr)
    when 'ConditionalExpr'
      evaluate_condition(expr)
    when 'ImportExpr'
      @scope_attributes.merge!(@scope_attributes[expr.name].scope_attributes)
    else
      puts "I can't evaluate a #{expr.class}!"
    end
  end

  protected

  # The attributes of the parent.
  def parent_attributes
    @parent ? @parent.attributes : {}
  end

  def evaluate_list(expr)
    values = expr.values.map { |v| eval_one(v) }
    ListScope.new(self, values)
  end

  def evaluate_function_call(expr)
    # Function call!
    name = expr.reference.name

    # Special case: assignment
    if name == '='
      assign(expr.args[0].name, eval_one(expr.args[1]))
    # Special case: dereference
    elsif name == '.'
      scope = eval_one(expr.args[0])
      raise FnRunError.new("Cannot dereference #{expr.args[0].to_s}!") unless scope.is_a? Scope

      scope.eval_one(expr.args[1])
    else
      f = attributes[expr.reference.name]
      raise FnRunError.new("#{name} is not a function") if f.nil? || !f.callable?

      f.call(*expr.args.map { |arg| eval_one(arg) })
    end
  end

  # Callable is:
  #  - A lambda (built-in)
  #  - A Block with a call_proc
  def callable?
    !@scope_attributes['call'].nil?
  end

  def evaluate_function_prototype(expr)
    scope = Scope.new(self)
    scope.assign('call', fnfn do |*call_args|
      arg_ids = expr.args
      unless arg_ids.length == call_args.length
        raise FnRunError.new("Expected #{arg_ids.length} args, got #{call_args.length}")
      end

      # Define the function scope with the arguments defined
      function_scope = Scope.new(self)
      arg_ids.each_with_index do |arg, idx|
        function_scope.assign(arg.name, call_args[idx])
      end

      # Evaluate the function
      function_scope.eval(expr.body)
    end)

    scope
  end

  def evaluate_block(expr)
    block_scope = Scope.new(self)

    # Evaluate the function
    block_scope.eval(expr.body)
  end

  def evaluate_condition(expr)
    expr.branches.each do |branch|
      result = eval_one(branch.condition)
      if result
        return eval(branch.body.body)
      end
    end
  end
end

# A Scope that wraps a Ruby lambda.
class FunctionScope < Scope
  def initialize(proc)
    super(nil)
    @proc = proc
  end

  # Override call to use the Ruby proc instead.
  def call(*args)
    @proc.call(*args)
  end

  def callable?
    true
  end
end

# Alias
def fnfn(&block)
  FunctionScope.new(block)
end

# The Scope that is defined when a file or REPL is loaded.
class TopLevelScope < Scope

  # A TopLevelScope has no Parent.
  # (This makes writing this class hard!)
  def initialize
    super(nil)

    # Globals
    @scope_attributes = {
      '!' => fnfn { |a| !a },
      '+' => fnfn { |a,b| a+b },
      '-' => fnfn { |a,b| a-b },
      '*' => fnfn { |a,b| a*b },
      '/' => fnfn { |a,b| a/b },
      'and' => fnfn { |a,b| a && b },
      'or' => fnfn { |a,b| a || b },
      'eq' => fnfn { |a,b| a == b },
      'print' => fnfn { |a| puts a.to_s },
    }
  end

end

# A Scope that wraps a Ruby value.
class ValueScope < Scope
  attr_reader :value

  def initialize(parent, value)
    super(parent)
    @value = value
  end

  def to_s
    value
  end

end

# Scope wrapper around Numeric.
class NumberScope < ValueScope

  def initialize(parent, rb_number)
    super(parent, rb_number)

    # Number methods
    @scope_attributes = {}
  end

  def +(other)
    NumberScope.new(@parent, value + other.value)
  end

  def -(other)
    NumberScope.new(@parent, value - other.value)
  end

  def *(other)
    NumberScope.new(@parent, value * other.value)
  end

  def /(other)
    NumberScope.new(@parent, value / other.value)
  end

end

# Scope wrapper around String.
class StringScope < ValueScope

  def initialize(parent, rb_string)
    super(parent, rb_string)

    # String methods
    @scope_attributes = {}
  end

end

# Scope wrapper around List.
class ListScope < ValueScope

  def initialize(parent, rb_list)
    super(parent, rb_list)

    # List methods
    @scope_attributes = {
      'first' => @value.first,
      'last' => @value.last,
      'each' => fnfn { |fn| each(fn) },
      'call' => fnfn { |idx| at(idx) },
    }
  end

  def at(idx)
    @value[idx.value]
  end

  def each(fn)
    @value.each do |v|
      fn.call(v)
    end

    # We return an Empty Scope to avoid chaining
    Scope.new(nil)
  end

  def to_s
    @value.map { |v| v.to_s }.to_s
  end
end
