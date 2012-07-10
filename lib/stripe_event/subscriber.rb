module StripeEvent
  class Subscriber
    def initialize(names, &block)
      @names = names
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
      @names.each do |name|
        raise InvalidEventType.new(name) if !TYPES.include?(name)
      end
    end
  end
end
