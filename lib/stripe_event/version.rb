module StripeEvent
  module Version
    module_function

    KEYS = %i[major minor patch].freeze

    # Major version.
    #
    # @return [Integer]
    def major
      2
    end

    # Minor version.
    #
    # @return [Integer]
    def minor
      0
    end

    # Patch version.
    #
    # @return [Integer]
    def patch
      0
    end

    # Returns a hash representation of version.
    #
    # @return [Hash]
    def to_h
      Hash[KEYS.zip(to_a)]
    end

    # Returns a string representation of version.
    #
    # @return [Array]
    def to_a
      [major, minor, patch]
    end

    # Returns an array representation of version.
    #
    # @return [String]
    def to_s
      to_a.join('.')
    end
  end
end
