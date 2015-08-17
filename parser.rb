# Expressions
NumberExpr = Struct.new(:value)
StringExpr = Struct.new(:value)
IdentifierExpr = Struct.new(:name)

FunctionCallExpr = Struct.new(:reference, :args)
FunctionPrototypeExpr = Struct.new(:args, :body)

AssignmentExpr = Struct.new(:reference, :definition)

UseExpr = Struct.new(:name)
ImportExpr = Struct.new(:name)

class Parser

  def self.parse(tokens)
    new(tokens).parse
  end

  def initialize(tokens)
    @initial_tokens = tokens
  end

  def shift_token!
    @tokens.shift
  end

  def current_token
    @tokens.first
  end

  def peek_token(ahead = 1)
    @tokens[ahead]
  end

  def file_end?
    @tokens.empty?
  end

  def parse
    @tokens = @initial_tokens
    @primaries = []

    @indent_stack = [0]
    shift_token!

    loop do
      break if current_token.nil?
      expr = parse_primary
      @primaries.push(expr)
    end

    @primaries
  end

  def parse_primary
    expr = case current_token.type
    when :identifier
      # This could be:
      #   :identifier [value]
      #   :identifier :eq ... [assignment]
      #   :identifier :bracket_open ... [functionCall]
      # So we check to see what we have next.
      case peek_token.type
      when :eq
        parse_assignment
      when :bracket_open
        parse_function_call
      else
        parse_value
      end
    when :number, :string
      parse_value
    when :bracket_open
      parse_brackets
    when :use
      parse_use
    when :import
      parse_import
    else
      # For development only! This should just fail.
      puts "You cannot start an expression with #{current_token}!"
      shift_token!
      nil
    end

    if current_token && current_token.type == :end_statement
      shift_token!
    end

    expr
  end

  # def parse_reference(parent = nil)
  #   unless current_token.type == :identifier
  #     fail "WTF? Called parse_identifier with #{current_token}!"
  #   end
  #
  #   name = current_token.value
  #   if parent.nil?
  #     expr = ReferenceExpr.new(name)
  #   else
  #     expr = PropertyReferenceExpr.new(parent, name)
  #   end
  #
  #   shift_token! # Eat :identifier
  #
  #   if current_token.type == :property
  #     shift_token! # Eat :property
  #     expr = parse_reference(expr)
  #   end
  #
  #   expr
  # end

  def parse_value
    lhs =
      case current_token.type
      when :identifier
        case peek_token.type
        when :bracket_open
          parse_function_call
        else
          parse_identifier
        end
      when :number, :string
        parse_literal
      when :bracket_open
        parse_brackets
      else
        fail "parse_value called on non-value #{current_token}"
      end

    # Look-ahead for binary operations
    case current_token.type
    when :infix_operator
      op = current_token.value
      shift_token! # Eat :plus
      rhs = parse_value
      FunctionCallExpr.new(IdentifierExpr.new(op), [lhs, rhs])
    else
      lhs
    end
  end

  def parse_function_call
    unless current_token.type == :identifier
      fail "WTF? Called parse_function_call with #{current_token}!"
    end

    identifier_expr = IdentifierExpr.new(current_token.value)
    shift_token! # Eat :identifier

    parameter_list = parse_parameter_list
    FunctionPrototypeExpr.new(identifier_expr, parameter_list)
  end

  def parse_parameter_list
    unless current_token.type == :bracket_open
      fail "WTF? Expecting (, got #{current_token} in function call!"
    end

    shift_token! # Eat :bracket_open

    # Get the parameter list
    parameter_list = []
    while(current_token.type != :bracket_close) do
      parameter_expr = parse_parameter
      parameter_list.push(parameter_expr)

      case current_token.type
      when :comma
        shift_token!
      when :bracket_close
        break
      else
        fail "Unexpected token #{current_token} in function call"
      end
    end

    shift_token! # Eat :bracket_close

    parameter_list
  end

  def parse_parameter
    case current_token.type
    when :bracket_open
      parse_function_definition
    else
      parse_value
    end
  end

  def parse_assignment
    unless current_token.type == :identifier
      fail "WTF? Called parse_function_call with #{current_token}!"
    end

    identifier_expr = IdentifierExpr.new(current_token.value)
    shift_token!

    unless current_token.type == :eq
      fail "WTF? Called parse_assignment_on_reference with #{current_token}!"
    end

    shift_token! # Eat :eq
    defintion_expr = parse_definition
    AssignmentExpr.new(identifier_expr, defintion_expr)
  end

  def parse_definition
    case current_token.type
    when :bracket_open
      parse_function_definition
    when :number, :string
      parse_literal
    end
  end

  def parse_function_definition
    argument_list = parse_argument_list
    function_body = parse_function_body
    FunctionPrototypeExpr.new(argument_list, function_body)
  end

  def parse_argument_list
    unless current_token.type == :bracket_open
      fail "WTF? Expecting (, got #{current_token} in function definition!"
    end

    shift_token! # Eat :bracket_open

    # Get the argument list
    argument_list = []
    while(current_token.type != :bracket_close) do
      unless current_token.type == :identifier
        fail "WTF? Expecting identifier, got #{current_token} in argument list!"
      end

      argument_list.push(IdentifierExpr.new(current_token.value))
      shift_token! # Eat :identifier

      case current_token.type
      when :comma
        shift_token!
      when :bracket_close
        break
      else
        fail "Expected ',' or ')', got #{current_token}!"
      end
    end

    shift_token! # Eat :bracket_close

    argument_list
  end

  def parse_function_body
    unless current_token.type == :block_open
      fail "WTF? Expecting {, got #{current_token} in function definition!"
    end

    shift_token! # Eat :block_open

    expr_list = []
    while(current_token.type != :block_close && !(file_end?)) do
      expr_list.push(parse_primary)
    end

    if current_token.type != :block_close
      fail "End of file reached before block closed."
    end
    shift_token! # Eat :block_close

    expr_list
  end

  def parse_literal
    case current_token.type
    when :number
      parse_number
    when :string
      parse_string
    else
      fail "parse_literal for #{current_token} failed."
    end
  end

  def parse_brackets
    unless current_token.type == :bracket_open
      fail "WTF? Called parse_brackets with #{current_token}!"
    end

    # Move to the next token and get the bracketed expression.
    shift_token!

    # Guard against empty brackets
    if current_token.type == :bracket_close
      shift_token!
      return nil
    end

    # Get the bracketed expression
    expr = parse_primary

    # Ensure we now have a closing bracket
    if current_token.type != :bracket_close
      fail "Expected ')', got #{current_token}"
    end

    shift_token!

    expr
  end

  def parse_number
    shift_token_into!(NumberExpr)
  end

  def parse_string
    shift_token_into!(StringExpr)
  end

  def parse_identifier
    shift_token_into!(IdentifierExpr)
  end

  def parse_use
    shift_token! # Eat :use
    unless current_token.type == :identifier
      fail "Expecting identifier for use statement, got #{current_token.type}"
    end

    shift_token_into!(UseExpr)
  end

  def parse_import
    shift_token! # Eat :import
    unless current_token.type == :identifier
      fail "Expecting identifier for import statement, got #{current_token.type}"
    end

    shift_token_into!(ImportExpr)
  end

  def shift_token_into!(exprClass)
    expr = exprClass.new(current_token.value)
    shift_token!
    expr
  end

  # def indent!
  #   indent = @current_token.value.count(' ')
  #   last_indent = @indent_stack.last
  #
  #   if last_indent != indent
  #     puts "INDENT[#{@indent_stack.last} => #{indent}]"
  #   end
  #
  #   if indent > last_indent
  #     @indent_stack.push(indent)
  #   end
  #
  #   if indent < last_indent
  #     # Unroll the indent stack to the new indent
  #     split_stack = @indent_stack.slice_after(indent).to_a
  #     if split_stack.length == 1
  #       fail "Unexpected indent of #{indent}; expecting any of #{@indent_stack}"
  #     end
  #
  #     @indent_stack = split_stack.first
  #   end
  #
  #   shift_token!
  # end

end
