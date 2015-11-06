GRAMMAR = {
  :comment => /\A\#([^\n]*)/,

  :bracket_open => /\A\(/,
  :bracket_close => /\A\)/,

  :comma => /\A\,/,
  :end_statement => /\A\;/,

  # Reserved words/symbols
  :use => /\Ause/,
  :import => /\Aimport/,
  :when => /\Awhen/,
  :loop => /\Aloop/,

  # Infix operators
  :infix_operator => /\A(\+|\-|\*|\/|\.|\=|eq|or|and)/,

  # Blocks
  :block_open => /\A\{/,
  :block_close => /\A\}/,

  #:list_open => /\A\[/,
  #:list_close => /\A\]/,

  # Value literals
  :string => /\A\"([^\"]*)\"/,
  :number => /\A([0-9]+)/,
  :boolean => /\A(true|false)/,

  # :identifier should be below all other tokens.
  # This saves me having to exclude all of the other tokens
  # in this regex.
  :identifier => /\A([^\#\(\)\,\;\+\-\*\/\.\=\|\>\{\}\"0-9\s]+)/,

  :space => /\A[\s\n]+/
}

SPECIAL_BEHAVIOURS = {
  # When we encounter a space, don't add a token.
  :space => lambda { |tokens| tokens.pop; tokens },
  :comment => lambda { |tokens| tokens.pop; tokens }
}

class Token
  attr_reader :type, :value

  def initialize(type, value = nil)
    @type = type
    @value = value
  end

  def to_s
    value_display = value ? "[#{value}]" : ''
    "#{@type}#{value_display}"
  end
end

class Tokeniser
  def self.tokenise(input_blob)
    new(input_blob).tokens
  end

  def initialize(input)
    @initial_input = input
    @tokens = nil
  end

  def tokens
    @tokens ||= process(@initial_input)
  end

  def process(input)
    tokens = []

    loop do
      input_at_start_of_iteration = input

      GRAMMAR.find do |token_type, re|
        input.match(re) do |matches|
          token = Token.new(token_type, matches.captures[0])
          tokens.push(token)

          if SPECIAL_BEHAVIOURS.key? token_type
            tokens = SPECIAL_BEHAVIOURS[token_type].call(tokens)
          end

          input = matches.post_match
        end
      end

      break if input == ''

      if input == input_at_start_of_iteration
        fail "Failed to tokenise:\n\n#{input}"
      end
    end

    tokens
  end
end
