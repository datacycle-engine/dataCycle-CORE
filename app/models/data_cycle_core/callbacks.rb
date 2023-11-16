# frozen_string_literal: true

module DataCycleCore
  class Callbacks
    def initialize(block = nil)
      tap { |proxy| block&.call(proxy) }
    end

    def method_missing(callback, *args, &block)
      super
    rescue NoMethodError
      raise "wrong number of arguments (#{args.size} for 0)" if args.present?

      callbacks[callback] = (callbacks[callback] || []) + [block] if block

      self
    end

    def execute_callback(callback, *)
      callbacks[callback].map { |c| c.call(*) } if callbacks.key?(callback)
    end

    protected

    def callbacks
      @callbacks ||= {}
    end
  end
end
