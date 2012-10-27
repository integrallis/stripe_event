module StripeEvent
  class Subscriber
    def initialize(*names)
      @names = names
      assert_valid_types!
    end

    def register(&block)
      ActiveSupport::Notifications.subscribe(pattern) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        block.call(event.payload)
      end
    end

    def pattern
      Regexp.union(@names.empty? ? TYPE_LIST : @names)
    end

    private

    def assert_valid_types!
      invalid_names = @names.select { |name| !TYPE_LIST.include?(name) }
      raise InvalidEventTypeError.new(invalid_names) if invalid_names.any?
    end
  end
end
