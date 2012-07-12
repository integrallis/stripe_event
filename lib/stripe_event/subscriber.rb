module StripeEvent
  class Subscriber
    def initialize(names, &block)
      @names = Array(names)
      @block = block
      ensure_valid_types!
    end
    
    def register
      ActiveSupport::Notifications.subscribe(pattern, proxied_block)
    end
    
    private
    
    def pattern
      Regexp.union(@names.empty? ? TYPES : @names)
    end
    
    def proxied_block
      lambda do |name, started, finished, id, payload|
        @block.call(payload[:event])
      end
    end
    
    def ensure_valid_types!
      invalid_names = @names.select { |name| !TYPES.include?(name) }
      raise InvalidEventType.new(invalid_names) if invalid_names.any?
    end
  end
end
