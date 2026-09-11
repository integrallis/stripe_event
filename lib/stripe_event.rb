require "active_support/notifications"
require "stripe"
require "stripe_event/engine" if defined?(Rails)

module StripeEvent
  class << self
    attr_accessor :adapter, :backend, :namespace, :event_filter
    attr_reader :signing_sources

    def configure(&block)
      raise ArgumentError, "must provide a block" unless block_given?
      block.arity.zero? ? instance_eval(&block) : yield(self)
    end
    alias :setup :configure

    def instrument(event, source: nil)
      scoped_namespace = source_namespace(source) unless source.nil?
      event = event_filter.call(event)
      return unless event

      scoped_name = scoped_namespace.call(event.type) if scoped_namespace
      result = backend.instrument namespace.call(event.type), event
      backend.instrument scoped_name, event if scoped_name
      result
    end

    def subscribe(name, callable = nil, source: nil, &block)
      callable ||= block
      subscription_namespace = source.nil? ? namespace : source_namespace(source)
      backend.subscribe subscription_namespace.to_regexp(name), adapter.call(callable)
    end

    def all(callable = nil, source: nil, &block)
      callable ||= block
      subscribe nil, callable, source: source
    end

    def listening?(name, source: nil)
      listening = backend.notifier.listening?(namespace.call(name))
      return listening if source.nil?
      scoped_name = source_namespace(source).call(name)
      listening || backend.notifier.listening?(scoped_name)
    end

    def signing_secret=(value)
      @signing_secrets = Array(value).compact
    end
    alias signing_secrets= signing_secret=

    def signing_secrets
      return unless @signing_secrets
      resolve_secrets(@signing_secrets)
    end

    def signing_secret
      secrets = signing_secrets
      secrets && secrets.first
    end

    def signing_sources=(sources)
      sources = {} if sources.nil?
      raise ArgumentError, "signing_sources must be a hash" unless sources.is_a?(Hash)

      @signing_sources = sources.each_with_object({}) do |(source, secrets), result|
        name = normalize_source(source)
        raise ArgumentError, "Duplicate signing source name" if result.key?(name)
        result[name] = secrets
      end.freeze
    end

    # Internal verification candidates. Resolve all providers before attempting
    # verification. A fixed mount removes source ambiguity before duplicate checks;
    # unrestricted mounts still reject secrets owned by more than one source.
    def signing_candidates(source: nil)
      candidates = Array(signing_secrets).map { |secret| [nil, secret.to_s] }
      signing_sources.each do |source, secrets|
        resolve_secrets(secrets).each { |secret| candidates << [source, secret.to_s] }
      end
      candidates.reject! { |_, secret| secret.strip.empty? }
      candidates.select! { |name, _| name == source.to_s } unless source.nil?

      owners = {}
      candidates.each do |source, secret|
        if owners.key?(secret) && owners[secret] != source
          raise ArgumentError, "A signing secret cannot belong to multiple sources (including unscoped secrets)"
        end
        owners[secret] = source
      end
      candidates.uniq
    end

    private

    def resolve_secrets(value)
      Array(value).flat_map { |secret| secret.respond_to?(:call) ? secret.call : secret }.compact
    end

    def normalize_source(source)
      unless (source.is_a?(String) || source.is_a?(Symbol)) && !source.to_s.empty? && source.to_s !~ /[\r\n]/
        raise ArgumentError, "source must be a nonempty, single-line string or symbol"
      end
      source.to_s.dup.freeze
    end

    def source_namespace(source)
      source = normalize_source(source)
      # A separate, length-prefixed namespace keeps global subscribers and
      # source names containing delimiters from matching unrelated deliveries.
      Namespace.new("stripe_event_source:#{source.bytesize}:#{source}:#{namespace.call}", "")
    end
  end

  class Namespace < Struct.new(:value, :delimiter)
    def call(name = nil)
      "#{value}#{delimiter}#{name}"
    end

    def to_regexp(name = nil)
      %r{^#{Regexp.escape call(name)}}
    end
  end

  class NotificationAdapter < Struct.new(:subscriber)
    def self.call(callable)
      new(callable)
    end

    def call(*args)
      payload = args.last
      subscriber.call(payload)
    end
  end

  class Error < StandardError; end
  class UnauthorizedError < Error; end
  class ProcessError < Error; end

  self.adapter = NotificationAdapter
  self.backend = ActiveSupport::Notifications
  self.namespace = Namespace.new("stripe_event", ".")
  self.event_filter = lambda { |event| event }
  self.signing_sources = {}
end
