module StripeEvent
  class Namespace
    attr_accessor :value, :delimiter

    def initialize(value, delimiter)
      @value = value
      @delimiter = delimiter
    end

    def call(name = nil)
      [value, delimiter, name].join
    end

    def to_regexp(name = nil)
      /^#{Regexp.escape(call(name))}/
    end
  end
end
